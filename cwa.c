#define CLIENT_SPACE

#include "clockwork.h"

#include <getopt.h>
#include <glob.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/time.h>

#include "proto.h"
#include "policy.h"
#include "userdb.h"
#include "client.h"
#include "resources.h"
#include "augcw.h"
#include "db.h"

static client* cwa_options(int argc, char **argv);
static void show_help(void);

static int gather_facts_from_script(const char *script, struct hash *facts);
static int gather_facts(client *c);
static void print_facts(struct hash *facts);
static int get_policy(client *c);
static int get_file(protocol_session *session, sha1 *checksum, int fd);
static int enforce_policy(client *c, struct job *job);
static int autodetect_managers(struct resource_env *env, const struct hash *facts);
static void print_report(FILE *io, struct report *r);
static int print_summary(FILE *io, struct job *job);
static int send_report(client *c, struct job *job);
static int save_report(client *c, struct job *job);

/**************************************************************/

int main(int argc, char **argv)
{
	client *c;
	struct job *job;

	c = cwa_options(argc, argv);
	if (client_options(c) != 0) {
		fprintf(stderr, "Unable to process server options");
		exit(2);
	}
	c->log_level = log_set(c->log_level);
	INFO("Log level is %s (%u)", log_level_name(c->log_level), c->log_level);
	INFO("Running in mode %u", c->mode);

	INFO("Gathering facts");
	if (gather_facts(c) != 0) {
		CRITICAL("Unable to gather facts");
		exit(1);
	}

	if (c->mode == CLIENT_MODE_FACTS) {
		print_facts(c->facts);
		exit(0);
	}

	if (client_connect(c) != 0) {
		exit(1);
	}

	if (client_hello(c) != 0) {
		ERROR("Server-side verification failed.");
		printf("Local certificate not found.  Run cwcert(1)\n");

		client_bye(c);
		exit(2);
	}

	job = job_new();
	get_policy(c);
	enforce_policy(c, job);
	print_summary(stdout, job);
	if (c->mode != CLIENT_MODE_TEST) {
		if (save_report(c, job) != 0) {
			WARNING("Unable to store report in local database.");
		}
		if (send_report(c, job) != 0) {
			WARNING("Unable to send report to master database.");
		}
	}

	client_bye(c);
	return 0;
}

/**************************************************************/

static client* cwa_options(int argc, char **argv)
{
	client *c;

	const char *short_opts = "h?c:s:p:nvqF";
	struct option long_opts[] = {
		{ "help",   no_argument,       NULL, 'h' },
		{ "config", required_argument, NULL, 'c' },
		{ "server", required_argument, NULL, 's' },
		{ "port",   required_argument, NULL, 'p' },
		{ "dry-run", no_argument,      NULL, 'n' },
		{ "verbose", no_argument,      NULL, 'v' },
		{ "quiet",  no_argument,       NULL, 'q' },
		{ "facts",  no_argument,       NULL, 'F' },
		{ 0, 0, 0, 0 },
	};

	int opt, idx = 0;

	c = xmalloc(sizeof(client));

	while ( (opt = getopt_long(argc, argv, short_opts, long_opts, &idx)) != -1) {
		switch(opt) {
		case 'h':
		case '?':
			show_help();
			exit(0);
		case 'c':
			free(c->config_file);
			c->config_file = strdup(optarg);
			break;
		case 's':
			free(c->s_address);
			c->s_address = strdup(optarg);
			break;
		case 'p':
			free(c->s_port);
			c->s_port = strdup(optarg);
			break;
		case 'n':
			c->mode = CLIENT_MODE_TEST;
			break;
		case 'v':
			c->log_level++;
			break;
		case 'q':
			c->log_level--;
			break;
		case 'F':
			c->mode = CLIENT_MODE_FACTS;
			break;
		}
	}

	return c;
}

static void show_help(void)
{
	printf("USAGE: cwa [OPTIONS]\n"
	       "\n"
	       "  -h, --help            Show this helpful message.\n"
	       "                        (for more in-depth help, check the man pages.)\n"
	       "\n"
	       "  -n, --dry-run         Do not enforce the policy locally, just verify policy\n"
	       "                        retrieval and fact gathering.\n"
	       "\n"
	       "  -c, --config          Specify the path to an alternate configuration file.\n"
	       "\n"
	       "  -s, --server          Override the name (IP or DNS) of the policy master.\n"
	       "\n"
	       "  -p, --port            Override the TCP port number to connect to.\n"
	       "\n");
}

static int gather_facts_from_script(const char *script, struct hash *facts)
{
	pid_t pid;
	int pipefd[2];
	FILE *input;
	char *path_copy, *arg0;

	path_copy = strdup(script);
	arg0 = basename(path_copy);
	free(path_copy);

	INFO("Processing script %s", script);

	if (pipe(pipefd) != 0) {
		perror("gather_facts");
		return -1;
	}

	pid = fork();
	switch (pid) {
	case -1:
		perror("gather_facts: fork");
		return -1;

	case 0: /* in child */
		close(pipefd[0]);
		close(0); close(1); close(2);

		dup2(pipefd[1], 1); /* dup pipe as stdout */

		execl(script, arg0, NULL);
		exit(1); /* if execl returns, we failed */

	default: /* in parent */
		close(pipefd[1]);
		input = fdopen(pipefd[0], "r");

		fact_read(input, facts);
		waitpid(pid, NULL, 0);
		fclose(input);
		close(pipefd[0]);

		return 0;
	}
}

static int gather_facts(client *c)
{
	glob_t scripts;
	size_t i;

	c->facts = hash_new();

	switch(glob(c->gatherers, GLOB_MARK, NULL, &scripts)) {
	case GLOB_NOMATCH:
		globfree(&scripts);
		if (gather_facts_from_script(c->gatherers, c->facts) != 0) {
			hash_free(c->facts);
			return -1;
		}
		return 0;

	case GLOB_NOSPACE:
	case GLOB_ABORTED:
		hash_free(c->facts);
		return -1;

	}

	for (i = 0; i < scripts.gl_pathc; i++) {
		if (gather_facts_from_script(scripts.gl_pathv[i], c->facts) != 0) {
			hash_free(c->facts);
			globfree(&scripts);
			return -1;
		}
	}

	globfree(&scripts);
	return 0;
}

static void print_facts(struct hash *facts)
{
	struct hash_cursor cur;
	char *key, *val;

	for_each_key_value(facts, &cur, key, val) {
		printf("%s = %s\n", key, val);
	}
}

static int get_policy(client *c)
{
	if (pdu_send_FACTS(&c->session, c->facts) < 0) { goto disconnect; }

	if (pdu_receive(&c->session) < 0) {
		CRITICAL("Error: %u - %s", c->session.errnum, c->session.errstr);
		goto disconnect;
	}

	if (RECV_PDU(&c->session)->op != PROTOCOL_OP_POLICY) {
		CRITICAL("Unexpected op from server: %u", RECV_PDU(&c->session)->op);
		pdu_send_ERROR(&c->session, 505, "Protocol Error");
		goto disconnect;
	}

	if (pdu_decode_POLICY(RECV_PDU(&c->session), &c->policy) != 0) {
		CRITICAL("Unable to decode POLICY PDU");
		goto disconnect;
	}

	return 0;

disconnect:
	DEBUG("get_policy forcing a disconnect");
	client_disconnect(c);
	exit(1);
}

static int get_file(protocol_session *session, sha1 *checksum, int fd)
{
	size_t bytes = 0, n = 0;

	if (pdu_send_FILE(session, checksum) != 0) { return -1; }

	do {
		if (pdu_receive(session) != 0) {
			return -1;
		}
		if (RECV_PDU(session)->op != PROTOCOL_OP_DATA) {
			pdu_send_ERROR(session, 505, "Protocol Error");
			return -1;
		}

		n = RECV_PDU(session)->len;
		write(fd, RECV_PDU(session)->data, n);
		bytes += n;
	} while(n > 0);

	return bytes;
}

static int enforce_policy(client *c, struct job *job)
{
	struct resource_env env;
	struct resource *res;
	struct res_file *rf;

	struct report *r;
	int pipefd[2];
	ssize_t bytes = 0;

	if (job_start(job) != 0) {
		CRITICAL("Unable to start job timer");
		exit(2);
	}

	if (autodetect_managers(&env, c->facts) != 0) {
		CRITICAL("Unable to auto-detect appropriate managers.");
		exit(2);
	}

	DEBUG("Initializing Augeas subsystem");
	env.aug_context = augcw_init();
	if (!env.aug_context) {
		CRITICAL("Unable to initialize Augeas subsystem");
		exit(2);
	}

	if ((env.user_pwdb  = pwdb_init(SYS_PASSWD)) == NULL
	 || (env.user_spdb  = spdb_init(SYS_SHADOW)) == NULL
	 || (env.group_grdb = grdb_init(SYS_GROUP))  == NULL
	 || (env.group_sgdb = sgdb_init(SYS_GSHADOW)) == NULL) {
		CRITICAL("Unable to initialize user / group database(s)");
		exit(2);
	}

	if (c->mode == CLIENT_MODE_TEST) {
		INFO("Enforcement skipped (--dry-run specified)");
	} else {
		INFO("Enforcing policy on local system");
	}

	/* Remediate all */
	for_each_resource(res, c->policy) {
		DEBUG("Fixing up %s", res->key);

		env.file_fd = -1;
		env.file_len = 0;
		if (resource_stat(res, &env) != 0) {
			CRITICAL("Failed to stat %s", res->key);
			exit(2);
		}

		if (res->type == RES_FILE) {
			rf = (struct res_file*)(res->resource);
			if (DIFFERENT(rf, RES_FILE_SHA1)) {
				if (pipe(pipefd) != 0) {
					pipefd[0] = -1;
				} else {
					DEBUG("Attempting to retrieve file contents for %s", rf->rf_lpath);
					bytes = get_file(&c->session, &rf->rf_rsha1, pipefd[1]);
					if (bytes <= 0) {
						close(pipefd[0]);
						close(pipefd[1]);

						pipefd[0] = -1;
					}
				}
				env.file_fd = pipefd[0];
				env.file_len = bytes;
			}
		}

		r = resource_fixup(res, c->mode == CLIENT_MODE_TEST, &env);
		if (r->compliant && r->fixed) {
			policy_notify(c->policy, res);
		}

		if (res->type == RES_FILE) {
			close(env.file_fd);
		}
		list_add_tail(&r->l, &job->reports);
	}

	if (c->mode != CLIENT_MODE_TEST) {
		pwdb_write(env.user_pwdb,  SYS_PASSWD);
		spdb_write(env.user_spdb,  SYS_SHADOW);
		grdb_write(env.group_grdb, SYS_GROUP);
		sgdb_write(env.group_sgdb, SYS_GSHADOW);

		if (aug_save(env.aug_context) != 0) {
			CRITICAL("augeas save failed; sub-config resources not properly saved!");
			augcw_errors(env.aug_context);
			exit(2);
		}
		aug_close(env.aug_context);
	}

	if (job_end(job) != 0) {
		CRITICAL("Unable to stop job timer");
		exit(2);
	}

	return 0;
}

static int autodetect_managers(struct resource_env *env, const struct hash *facts)
{
	assert(env);
	assert(facts);

	const char *dist = hash_get(facts, "lsb.distro.id");
	if (!dist) { return -1; }

	if (strcmp(dist, "Ubuntu") == 0) {
		INFO("Using 'debian' service manager");
		env->service_manager = SM_debian;

		INFO("Using 'dpkg/apt' package manager");
		env->package_manager = PM_dpkg_apt;

	} else {
		return -1;
	}

	return 0;
}

static void print_report(FILE *io, struct report *r)
{
	char buf[80];
	struct action *a;

	if (snprintf(buf, 67, "%s: %s", r->res_type, r->res_key) > 67) {
		memcpy(buf + 67 - 1 - 3, "...", 3);
	}
	buf[66] = '\0';

	fprintf(io, "%-66s%14s\n", buf, (r->compliant ? (r->fixed ? "FIXED": "OK") : "NON-COMPLIANT"));

	for_each_action(a, r) {
		memcpy(buf, a->summary, 70);
		buf[70] = '\0';

		if (strlen(a->summary) > 70) {
			memcpy(buf + 71 - 1 - 3, "...", 3);
		}

		fprintf(io, " - %-70s%7s\n", buf,
		        (a->result == ACTION_SUCCEEDED ? "done" :
		         (a->result == ACTION_FAILED ? "failed" : "skipped")));
	}
}

static int print_summary(FILE *io, struct job *job)
{
	struct report *r;
	size_t ok = 0, fixed = 0, non = 0;

	for_each_report(r, job) {
		if (r->compliant && !r->fixed) {
			print_report(io, r);
			ok++;
		}
	}
	fprintf(io, "\n");

	for_each_report(r, job) {
		if (!r->compliant || r->fixed) {
			print_report(io, r);
			fprintf(io, "\n");

			if (r->fixed) {
				fixed++;
			} else {
				non++;
			}
		}
	}

	fprintf(io, "%u resource(s); %u OK, %u fixed, %u non-compliant\n",
	        (ok+fixed+non), ok, fixed, non);
	fprintf(io, "run duration: %0.2fs\n", job->duration / 1000000.0);

	return 0;
}

static int send_report(client *c, struct job *job)
{
	if (pdu_send_REPORT(&c->session, job) < 0) { goto disconnect; }
	if (pdu_receive(&c->session) < 0) {
		goto disconnect;
	}

	if (RECV_PDU(&c->session)->op != PROTOCOL_OP_BYE) {
		CRITICAL("Unexpected op from server: %u", RECV_PDU(&c->session)->op);
		pdu_send_ERROR(&c->session, 505, "Protocol Error");
		goto disconnect;
	}

	return 0;

disconnect:
	DEBUG("send_report forcing a disconnect");
	client_disconnect(c);
	exit(1);
}

static int save_report(client *c, struct job *job)
{
	DB *db;
	db = db_open(DB_AGENT, c->db_file);
	if (!db) {
		return -1;
	}

	if (agentdb_store_report(db, job) != 0) {
		db_close(db);
		return -1;
	}

	db_close(db);
	return 0;
}
