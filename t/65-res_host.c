/*
  Copyright 2011-2015 James Hunt <james@jameshunt.us>

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
#include "../src/clockwork.h"
#include "../src/resources.h"

#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

TESTS {
	subtest {
		struct res_host *host;
		char *key;

		host = res_host_new("localhost");
		key = res_host_key(host);
		is_string(key, "host:localhost", "host key");
		free(key);
		res_host_free(host);
	}

	subtest {
		ok(res_host_norm(NULL, NULL, NULL) == 0, "res_host_norm is a NOOP");
	}

	subtest {
		res_host_free(NULL);
		pass("res_host_free(NULL) doesn't segfault");
	}

	subtest {
		struct res_host *rh;

		rh = res_host_new("host1");
		res_host_set(rh, "ip", "192.168.1.1");
		res_host_set(rh, "alias", "host1.example.net");

		ok(res_host_match(rh, "hostname", "host1")      == 0, "match hostname=host1");
		ok(res_host_match(rh, "ip", "192.168.1.1")      == 0, "match ip=192.168.1.1");
		ok(res_host_match(rh, "address", "192.168.1.1") == 0, "match address=192.168.1.1");

		ok(res_host_match(rh, "hostname", "h2")     != 0, "!match hostname=h2");
		ok(res_host_match(rh, "ip", "1.1.1.1")      != 0, "!match ip=1.1.1.1");
		ok(res_host_match(rh, "address", "1.1.1.1") != 0, "!match address=1.1.1.1");

		ok(res_host_match(rh, "alias", "host1.example.net") != 0,
				"alias is not a matchable attr");

		res_host_free(rh);
	}

	subtest {
		struct res_host *rh;
		hash_t *h;

		isnt_null(h = vmalloc(sizeof(hash_t)), "created hash");
		isnt_null(rh = res_host_new("localhost"), "created res_host");

		ok(res_host_attrs(rh, h) == 0, "got host attrs");
		is_string(hash_get(h, "hostname"), "localhost", "h.hostname");
		is_string(hash_get(h, "present"),  "yes",       "h.present"); // default
		is_null(hash_get(h, "ip"),      "h.ip is unset");
		is_null(hash_get(h, "aliases"), "h.aliases is unset");

		res_host_set(rh, "ip", "192.168.1.10");
		res_host_set(rh, "alias", "localhost.localdomain");
		res_host_set(rh, "alias", "special");

		ok(res_host_attrs(rh, h) == 0, "got host attrs");
		is_string(hash_get(h, "ip"),      "192.168.1.10",                  "h.ip");
		is_string(hash_get(h, "aliases"), "localhost.localdomain special", "h.aliases");

		res_host_set(rh, "present", "no");
		ok(res_host_attrs(rh, h) == 0, "got host attrs");
		is_string(hash_get(h, "present"),  "no", "h.present");

		hash_done(h, 1);
		free(h);
		res_host_free(rh);
	}

	done_testing();
}
