#include <assert.h>
#include <stdlib.h>
#include <string.h>

#include "stringlist.h"

#define INIT_LEN   16
#define EXPAND_LEN  8


#define _stringlist_full(sl) ((sl)->num == (sl)->len - 1)
static int _stringlist_expand(stringlist*, size_t);
static int _stringlist_reduce(stringlist*);

static int _stringlist_expand(stringlist *sl, size_t expand)
{
	assert(sl);
	assert(expand > 0);

	char **s;

	expand += sl->len;
	s = realloc(sl->strings, expand * sizeof(char *));
	if (!s) {
		return -1;
	}

	sl->strings = s;
	for (; sl->len < expand; sl->len++) {
		sl->strings[sl->len] = NULL;
	}

	return 0;
}

/**
 * Walk the list and zip up NULL strings
 */
static int _stringlist_reduce(stringlist *sl)
{
	char **ins; char **ptr, **end;

	ptr = ins = sl->strings;
	end = sl->strings + sl->num;
	while (ins < end) {
		while (!*ptr && ptr++ < end) {
			sl->num--;
		}

		if (ptr == end) {
			break;
		}

		*ins++ = *ptr++;
	}

	return 0;
}

/*****************************************************************/

int _stringlist_strcmp_asc(const void *a, const void *b)
{
	/* params are pointers to char* */
	return strcmp(* (char * const *) a, * (char * const *) b);
}

int _stringlist_strcmp_desc(const void *a, const void *b)
{
	/* params are pointers to char* */
	return -1 * strcmp(* (char * const *) a, * (char * const *) b);
}

stringlist* stringlist_new(void)
{
	stringlist *sl;

	sl = malloc(sizeof(stringlist));
	if (!sl) {
		return NULL;
	}

	sl->num = 0;
	sl->len = INIT_LEN;
	sl->strings = calloc(sl->len, sizeof(char *));
	if (!sl->strings) {
		free(sl);
		return NULL;
	}

	return sl;
}

void stringlist_free(stringlist *sl)
{
	assert(sl);

	size_t i;

	for (i = 0; i < sl->num; i++) {
		free(sl->strings[i]);
	}

	free(sl->strings);
	free(sl);
}

void stringlist_sort(stringlist* sl, sl_comparator cmp)
{
	assert(sl);
	assert(cmp);

	if (sl->num < 2) { return; }
	qsort(sl->strings, sl->num, sizeof(char *), cmp);
}

void stringlist_uniq(stringlist *sl)
{
	assert(sl);

	size_t i;

	if (sl->num < 2) { return; }

	stringlist_sort(sl, STRINGLIST_SORT_ASC);
	for (i = 0; i < sl->num - 1; i++) {
		if (strcmp(sl->strings[i], sl->strings[i+1]) == 0) {
			sl->strings[i] = NULL;
		}
	}
	_stringlist_reduce(sl);
}

int stringlist_search(stringlist *sl, const char* needle)
{
	assert(sl);
	assert(needle);

	size_t i;
	for (i = 0; i < sl->num; i++) {
		if ( strcmp(sl->strings[i], needle) == 0 ) {
			return 0;
		}
	}
	return -1;
}

int stringlist_add(stringlist *sl, const char* str)
{
	assert(sl);
	assert(str);

	/* expand as needed */
	if (_stringlist_full(sl) && _stringlist_expand(sl, EXPAND_LEN) != 0) {
		return -1;
	}

	sl->strings[sl->num] = strdup(str);
	sl->num++;
	sl->strings[sl->num] = NULL;

	return 0;
}

int stringlist_remove(stringlist *sl, const char *str)
{
	assert(sl);
	assert(str);

	char *removed = NULL;
	size_t i;
	for (i = 0; i < sl->num; i++) {
		if (strcmp(sl->strings[i], str) == 0) {
			removed = sl->strings[i];
			break;
		}
	}

	for (; i < sl->num; i++) {
		sl->strings[i] = sl->strings[i+1];
	}

	if (removed) {
		sl->num--;
		free(removed);
		return 0;
	}

	return -1;
}