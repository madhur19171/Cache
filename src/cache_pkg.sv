package cache_pkg;
	parameter ADDRESS_WIDTH = 32;
	parameter SETS = 1024;
	parameter WAYS = 2;
	parameter CACHE_LINE_SIZE = 32;
	parameter TAG_WIDTH = ADDRESS_WIDTH - ($clog2(SETS) + $clog2(CACHE_LINE_SIZE / 8));

	parameter STROBE_WIDTH = (CACHE_LINE_SIZE / 8);

endpackage


package memory_pkg;
	parameter MEMORY_BUS_WIDTH = 32;
	parameter ADDRESS_WIDTH = 32;

	parameter STROBE_WIDTH = (MEMORY_BUS_WIDTH / 8);

	parameter ENTRIES = 1024;
	parameter DELAY = 4;
endpackage

package interface_pkg;

	typedef struct packed {
		logic                                       valid;
		logic [cache_pkg::ADDRESS_WIDTH - 1 : 0] 	address;
		logic [cache_pkg::CACHE_LINE_SIZE - 1 : 0]	data;
		logic [cache_pkg::STROBE_WIDTH - 1 : 0] 	strobe;
		logic 										wen;
	} CPU_Request;

	typedef struct packed {
		logic [cache_pkg::CACHE_LINE_SIZE - 1 : 0]	data;
		logic 										hit;
	} CPU_Response;

	typedef struct packed {
		logic                                       	valid;
		logic [memory_pkg::ADDRESS_WIDTH - 1 : 0] 		address;
		logic [memory_pkg::MEMORY_BUS_WIDTH - 1 : 0]	data;
		logic [memory_pkg::STROBE_WIDTH - 1 : 0] 		strobe;
		logic 											wen;
	} Memory_Request;

	typedef struct packed {
		logic [memory_pkg::MEMORY_BUS_WIDTH - 1 : 0]	data;
		logic 											valid;
	} Memory_Response;

	typedef struct packed {
		logic 										valid;
		logic [cache_pkg::ADDRESS_WIDTH - 1 : 0]	address;
		logic [cache_pkg::CACHE_LINE_SIZE - 1 : 0]	data;		// Data to be written
		logic [cache_pkg::STROBE_WIDTH - 1 : 0]		strobe;
		logic [cache_pkg::WAYS - 1 : 0]				wenData;	// The way to write data in data array
		logic [cache_pkg::WAYS - 1 : 0]				wenTag;		// The way to write tag in tag array
		logic [cache_pkg::TAG_WIDTH - 1 : 0]		tag;		// Tag to be written
		logic [1 : 0][cache_pkg::WAYS - 1 : 0]		validDirty;
	} Cache_Request;

	typedef struct packed {
		logic [cache_pkg::CACHE_LINE_SIZE - 1 : 0] 	data;
		logic [1 : 0][cache_pkg::WAYS - 1 : 0]		validDirty;
	} Cache_Response;

endpackage