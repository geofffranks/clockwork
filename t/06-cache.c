/*
  Copyright 2011-2014 James Hunt <james@jameshunt.us>

  This file is part of Clockwork.

  Clockwork is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Clockwork is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Clockwork.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "test.h"

int global_counter = 0;
void destroyer(void *d)
{
	global_counter++;
}

TESTS {
	subtest { /* basic types */
		cw_cache_t *cc = cw_cache_new(4, 20);
		isnt_null(cc, "cw_cache_new created a new cache");
		is_int(cc->max_len,   4, "Set cc->max_len properly");
		is_int(cc->min_life, 20, "Set cc->min_life properly");

		cw_cache_purge(cc, 0);
		ok(1, "cw_cache_purge() on an empty cache doesn't crash");

		cw_cache_purge(cc, 1);
		ok(1, "cw_cache_purge(force) on an empty cache doesn't crash");

		is_null(cw_cache_get(cc, "xyzzy"),
				"No connection in the cache ident'd as 'xyzzy'");
		isnt_null(cw_cache_set(cc, "xyzzy", (void*)42),
			"Inserted 'xyzzy'");
		isnt_null(cw_cache_set(cc, "foobar", (void*)3),
			"Inserted 'foobar'");
		isnt_null(cw_cache_get(cc, "xyzzy"),
			"Found 'xyzzy'");
		isnt_null(cw_cache_get(cc, "foobar"),
			"Found 'foobar'");
		is_null(cw_cache_get(cc, "FooBar"),
			"Cache retrieval is case-sensitive");
		isnt_null(cw_cache_unset(cc, "foobar"),
			"Unset 'foobar'");
		is_null(cw_cache_get(cc, "foobar"),
			"'foobar' is gone now");

		cw_cache_purge(cc, 0);
		isnt_null(cw_cache_get(cc, "xyzzy"),
			"'xyzzy' survives the first cache purge");
		int life = -2;
		is_int(cw_cache_opt(cc, CW_CACHE_OPT_MINLIFE, &life), 0,
			"Set new minimum lifetime via cw_cache_opt");
		is_int(cc->min_life, -2, "cc->min_life updated");
		cw_cache_purge(cc, 0);
		is_null(cw_cache_get(cc, "xyzzy"),
			"'xyzzy' purged in the second cache purge");

		cw_cache_free(cc);
	}

	subtest { /* destroy callback */
		cw_cache_t *cc = cw_cache_new(4, -1);
		isnt_null(cc, "cw_cache_new created a new cache");
		is_int(cw_cache_opt(cc, CW_CACHE_OPT_DESTROY, destroyer), 0,
			"Set destroyer() as the destroy callback");

		isnt_null(cw_cache_set(cc, "key1", (void*)1), "key1 inserted");
		isnt_null(cw_cache_set(cc, "key2", (void*)2), "key2 inserted");
		isnt_null(cw_cache_set(cc, "key3", (void*)3), "key3 inserted");

		is_int(global_counter, 0, "global counter starts at 0");
		destroyer(NULL);
		is_int(global_counter, 1, "global counter increments on destroy()");
		cw_cache_purge(cc, 0);
		is_int(global_counter, 4, "global counter fired 4 times");

		cw_cache_free(cc);
	}

	subtest { /* for_each_cache_key */
		cw_cache_t *cc = cw_cache_new(4, 20);
		isnt_null(cc, "cw_cache_new created a new cache");

		isnt_null(cw_cache_set(cc, "xyzzy",  (void*)4), "Inserted 'xyzzy'");
		isnt_null(cw_cache_set(cc, "foobar", (void*)3), "Inserted 'foobar'");

		char *key;
		int i = 0;
		for_each_cache_key(cc,key) {
			i++;
			ok(strcmp(key, "xyzzy") == 0 || strcmp(key, "foobar") == 0,
				"Found key 'xyzzy'/'foobar'");
		}
		is_int(i, 2, "found 2 keys");

		cw_cache_free(cc);
	}

	subtest { /* tuning caches */
		cw_cache_t *cc = cw_cache_new(4, 20);

		is_int(cc->max_len,   4, "max_len is initially 4");
		is_int(cc->min_life, 20, "min_life is initially 20s");

		ok(cw_cache_tune(&cc, 0, 0) == 0, "cw_cache_tune(cc, 0, 0) is ok");
		is_int(cc->max_len,   4, "max_len is still 4");
		is_int(cc->min_life, 20, "min_life is still 20s");

		ok(cw_cache_tune(&cc, 0, 60) == 0, "changed cache life to 60s");
		is_int(cc->max_len,   4, "max_len is still 4");
		is_int(cc->min_life, 60, "min_life is 60s");

		ok(cw_cache_tune(&cc, 10, 15) == 0, "changed cache life to 15s / 10 entries");
		is_int(cc->max_len,  10, "max_len is now 10");
		is_int(cc->min_life, 15, "min_life is 15s now");

		ok(cw_cache_tune(&cc,  1, 0) != 0, "can't tune a cache to a lower max_len");

		cw_cache_free(cc);
	}

	subtest { /* too much! */
		cw_cache_t *cc = cw_cache_new(4, 20);

		isnt_null(cw_cache_set(cc, "key1", (void*)1), "key1 inserted");
		isnt_null(cw_cache_set(cc, "key2", (void*)2), "key2 inserted");
		isnt_null(cw_cache_set(cc, "key3", (void*)3), "key3 inserted");
		isnt_null(cw_cache_set(cc, "key4", (void*)4), "key4 inserted");

		is_null(cw_cache_set(cc, "key5", (void*)5), "key5 is too much");

		ok(cw_cache_tune(&cc, 128, 0) == 0, "extended cache from 4 slots to 128 slots");
		isnt_null(cw_cache_set(cc, "key5", (void*)5), "key5 inserted (post-tune)");

		cw_cache_free(cc);
	}

	subtest { /* touch */
		cw_cache_t *cc = cw_cache_new(4, 1);

		isnt_null(cw_cache_set(cc, "key1", (void*)1), "key1 inserted");
		isnt_null(cw_cache_set(cc, "key2", (void*)2), "key2 inserted");
		isnt_null(cw_cache_set(cc, "key3", (void*)3), "key3 inserted");
		cw_cache_touch(cc, "key1", cw_time_s() + 301);
		cw_cache_touch(cc, "key3",               300);

		cw_cache_purge(cc, 0);
		isnt_null(cw_cache_get(cc, "key1"), "key1 still alive and well");
		isnt_null(cw_cache_get(cc, "key2"), "key2 still alive and well");
		  is_null(cw_cache_get(cc, "key3"), "key3 expired (ts 300 is in the past)");

		diag("Sleeping for 3s");
		cw_sleep_ms(3000);
		cw_cache_purge(cc, 0);

		isnt_null(cw_cache_get(cc, "key1"), "key1 still alive and well");
		  is_null(cw_cache_get(cc, "key2"), "key2 expired after 1s");

		cw_cache_free(cc);
	}

	done_testing();
}