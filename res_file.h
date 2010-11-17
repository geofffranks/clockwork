#ifndef RES_FILE_H
#define RES_FILE_H

#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>

#include "list.h"
#include "sha1.h"

#define RES_FILE_NONE  0x00
#define RES_FILE_UID   0x01
#define RES_FILE_GID   0x02
#define RES_FILE_MODE  0x04
#define RES_FILE_SHA1  0x08

#define res_file_enforced(rf, flag)  (((rf)->rf_enf  & RES_FILE_ ## flag) == RES_FILE_ ## flag)
#define res_file_different(rf, flag) (((rf)->rf_diff & RES_FILE_ ## flag) == RES_FILE_ ## flag)

struct res_file {
	char        *key;        /* Unique Identifier; starts with "res_file:" */

	char        *rf_lpath;  /* Local path to the file */
	char        *rf_rpath;  /* Path to desired file */

	uid_t        rf_uid;    /* UID of file owner */
	gid_t        rf_gid;    /* GID of file group owner */
	mode_t       rf_mode;   /* File mode (perms only ATM) */

	sha1         rf_lsha1;  /* Local (actual) checksum */
	sha1         rf_rsha1;  /* Remote (expected) checksum */

	struct stat  rf_stat;   /* stat(2) of local file */
	unsigned int rf_enf;    /* enforce-compliance flags */
	unsigned int rf_diff;   /* out-of-compliance flags */

	struct list  res;       /* Node in policy list */
};

struct res_file* res_file_new(const char *key);
void res_file_free(struct res_file *rf);

int res_file_setattr(struct res_file *rf, const char *name, const char *value);

int res_file_set_uid(struct res_file *rf, uid_t uid);
int res_file_unset_uid(struct res_file *rf);

int res_file_set_gid(struct res_file *rf, gid_t gid);
int res_file_unset_gid(struct res_file *rf);

int res_file_set_mode(struct res_file *rf, mode_t mode);
int res_file_unset_mode(struct res_file *rf);

int res_file_set_path(struct res_file *rf, const char *path);
int res_file_unset_path(struct res_file *rf);

int res_file_set_source(struct res_file *rf, const char *path);
int res_file_unset_source(struct res_file *rf);

int res_file_stat(struct res_file *rf);
int res_file_remediate(struct res_file *rf);

int res_file_is_pack(const char *packed);
char* res_file_pack(struct res_file *rf);
struct res_file* res_file_unpack(const char *packed);

#endif
