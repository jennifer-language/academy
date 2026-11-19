# docs.j: an MCP server over stdio that serves the Jennifer
# documentation. Usage: jennifer run docs.j /path/to/jennifer/docs
include "docs.inc.j";

io.eprintf("jennifer-docs: %d pages from %s\n", len($pages), $root);
mcp.serveStdio(docsServer());
