import os
import sys
import argparse

from nasm_assembly import parsefile, printAssemblyDoc, writeASM, writeVHDL

RAM_BEGIN = """library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity RAM_8x256 is
	port(
		CLK     : in std_logic;
		DIN     : in std_logic_vector(7 downto 0);
		ADDR    : in std_logic_vector(7 downto 0);
		WE      : in std_logic;
		DOUT    : out std_logic_vector(7 downto 0);
		POS_255 : out std_logic_vector(7 downto 0)
	);
end RAM_8x256;

architecture rtl of RAM_8x256 is
    
	type RAM_t is array(0 to 255) of std_logic_vector(7 downto 0);
	signal read_address : std_logic_vector(7 downto 0) := (others => '0');

"""

RAM_END = """

begin

	process(CLK) is
	begin
		if falling_edge(CLK) then
			if WE = '1' then
				ram(to_integer(unsigned(ADDR))) <= DIN;
			end if;
			read_address <= ADDR;
		end if;
	end process;

	DOUT    <= ram(to_integer(unsigned(read_address)));
	POS_255 <= ram(255);

end architecture;
"""

    
def parse(args: argparse.Namespace):
    return parsefile(args.input)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="assembly format: [label:] mnemonic [operands] [;comment]")
    # required and mutual exclusive arguments
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("-hasm", action="store_true",
                        default=False,
                        dest="helpASM",
                        help="show the assembly documentation")
    group.add_argument("-i", action="store",
                        dest="input",
                        help="source file that must be processed. Ex: test.asm")
    # other arguments
    parser.add_argument("-o", action="store",
                        dest="output",
                        help="output the compiled code to a file. Ex: out.txt")
    parser.add_argument("-r", action="store_true",
                        default=False,
                        dest="ram",
                        help="generate and print the ram contents")
    parser.add_argument("-v", action="store_true",
                        default=False,
                        dest="verbose",
                        help="verbose mode")
    parser.add_argument("--overwrite", action="store_true",
                        default=False,
                        dest="overwrite",
                        help="overwrite output file")
    parser.add_argument("--version", action="version",
                        version="%(prog)s v0.3")
    # parse
    results = parser.parse_args()

    # verbose
    # print(results)
    if results.verbose:
        print(results)
        print(f"show_help_asm    = {results.helpASM!r}")
        print(f"input_file       = {results.input!r}")
        print(f"output_file      = {results.output!r}")
        print(f"verbose_mode     = {results.verbose!r}")
        print(f"print_VHDL_ram   = {results.ram!r}")
        print(f"overwrite        = {results.overwrite!r}")
        print("")

    if results.helpASM:
        printAssemblyDoc()
    else:
        print("")
        code = parse(results)
        if results.output is None:
            if results.ram:
                print( writeVHDL(results.input, code) )
            else:
                print( writeASM(code) )
        if not results.output is None:
            if results.input == results.output:
                raise IOError(f"source file and output file have the same name")
            if results.overwrite or not os.path.isfile(results.output):
                with open(results.output, "w") as f:
                    if results.ram:
                        f.writelines( RAM_BEGIN )
                        f.writelines( writeVHDL(results.input, code) )
                        f.writelines( RAM_END )
                    else:
                        f.writelines( writeASM(code) )
            else:
                raise IOError(f"{results.output!r} already exists")

