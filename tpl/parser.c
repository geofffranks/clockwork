#include <stdio.h>
#include <sys/stat.h>

#include "private.h"
#include "parser.h"
#include "../template.h"
#include "../log.h"

struct template* parse_template(const char *path)
{
	template_parser_context ctx;
	struct template *template;
	struct stat init_stat;

	/* check the file first. */
	if (stat(path, &init_stat) != 0) {
		return NULL;
	}

	ctx.warnings = ctx.errors = 0;

	yytpllex_init_extra(&ctx, &ctx.scanner);
	template_parser_use_file(path, &ctx);
	yytplparse(&ctx);

	template = ctx.root;

	yytpllex_destroy(ctx.scanner);
	xfree(ctx.file);

	if (ctx.errors > 0) {
		ERROR("Manifest parse errors encountered; aborting...");
		return NULL;
	}

	return template;
}

