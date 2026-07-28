# Ruby CI

An antenna for chkbuild servers.

# Development

To run this on local machine, following command can run development server:

```
% env DATABASE_URL=`heroku config:get -a rubyci DATABASE_URL` rails s
```

# MCP endpoint

`POST /mcp` serves the Model Context Protocol over Streamable HTTP (stateless, read-only, no authentication).

```
claude mcp add --transport http rubyci https://rubyci.org/mcp
```

Tools: `list_servers`, `current_status`, `report_history`, `search_failures`, `find_failure_origin`, `failing_servers`, `get_log_excerpt`.

Typical triage flow: `current_status` shows what is failing now, `failing_servers` shows how widespread a specific failure is, and `find_failure_origin` returns the first bad build with a github.com/ruby/ruby compare URL for the suspect commit range. Combine with a GitHub MCP server to enumerate commits in that range and a bugs.ruby-lang.org MCP server to search or file issues.

# Storage note

* To optimize S3 Access, extra directories should have 'o' character like 'log' and 'lcov'.

# License

Copyright (C) 2011-2012 NARUSE, Yui. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:
1. Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
SUCH DAMAGE.
