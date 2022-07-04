import os
import sys

# asm format:
#    mnemonic: (opcode, operands, complement)
#    operands:
#       a) One operand
#       "J"  = constant or label,        ex: "0x--" or "73" or "@label"            (jmp)
#       "L"  = labels,                   ex: "@loop"                               (.global)
#       "C"  = constants,                ex: "0x--" or "73"                        (.byte, .org)
#       "R"  = register,                 ex: "Rx" + minor opcode                   (inc, incc, dec, decc, not, rol, ror, lsl, lrl, jmpr, bz, bnz, bcs, bcc, beq, bneq, bgt, bgez, blt, blez)
#       b) Two operands
#       "RX" = constant or label,        ex: "Rx, ##" / "0x--" or "73" or "@label" (ld)
#       "RR" = register and register,    ex: "Rx, Ry"                              (add, sub, and, or, xor)
#       "RP" = register and pointer,     ex: "Rx, [Ry]"                            (ldr, str)
#       "XX" = ignore!                                                             (.equ)

asm = {
    ".global":   ("",     "L",  "10110000"), # .global = jmp
    ".byte":     ("",     "C",  ""),
    ".org":      ("",     "C",  ""),
    ".equ":      ("",     "XX", ""),     # compiler only constants (labels)

    "add":       ("0000", "RR", ""),
    "sub":       ("0001", "RR", ""),
    "inc":       ("0010", "R",  "00"),
    "incc":      ("0010", "R",  "01"),
    "dec":       ("0010", "R",  "10"),
    "decc":      ("0010", "R",  "11"),

    "and":       ("0011", "RR", ""),
    "or":        ("0100", "RR", ""),
    "not":       ("0101", "R",  "00"),
    "xor":       ("0110", "RR", ""),
    "rol":       ("0111", "R",  "00"),
    "ror":       ("0111", "R",  "01"),
    "lsl":       ("0111", "R",  "10"),
    "lsr":       ("0111", "R",  "11"),

    "push":      ("1000", "R",  "00"),
    "pop":       ("1000", "R",  "01"),
    "ld":        ("1000", "RX", "11"),
    "ldr":       ("1001", "RP", ""),
    "str":       ("1010", "RP", ""),

    "jmp":       ("1011", "J",  "0000"),
    "jmpr":      ("1011", "R",  "01"),
    "bz":        ("1011", "R",  "10"),
    "bnz":       ("1011", "R",  "11"),
    "bcs":       ("1100", "R",  "00"),
    "bcc":       ("1100", "R",  "01"),
    "beq":       ("1100", "R",  "10"),
    "bneq":      ("1100", "R",  "11"),
    "bgt":       ("1101", "R",  "00"),
    "bgez":      ("1101", "R",  "01"),
    "blt":       ("1101", "R",  "10"),
    "blez":      ("1101", "R",  "11"),
    
    "halt":      ("1111", "",   "0000"),
}

registers = {
    "ra": "00",
    "rb": "01",
    "rc": "10",
    "rd": "11"
}


def processAsmLine(line_no, mnemonic, operands, labels):
    if not mnemonic in asm:
        raise SyntaxError(f"Line {line_no}: Unrecognized mnemonic '{mnemonic}'")

    opcode, type_operands, complement = asm[mnemonic]

    if len(operands) != len(type_operands):
        raise SyntaxError(f"Line {line_no}: {mnemonic} requires {len(type_operands)} operand(s), found {operands}")

    def getLabel(label):
        try:
            ret = f"{labels.get(label):08b}"
        except:
            raise ValueError(f"Line {line_no}: label '{label}' not defined")
        return ret

    def getConstant(operand):
        try:
            val = int(operand, 0)
        except:
            raise SyntaxError(f"Line {line_no}: {mnemonic} operand '{operand}' is not a valid constant")
        return f"{val:08b}"

    ret = ""
    #print(f"Line {line_no}: {mnemonic} {operands}")
    if type_operands == "J":
        if operands[0][0] == "@":
            ret = getLabel(operands[0][1:])
        else:
            ret = getConstant(operands[0])
    if type_operands == "L":
        if operands[0][0] == "@":
            ret = getLabel(operands[0][1:])
        else:
            raise ValueError(f"Line {line_no}: label '{operands[0]}' not defined")
    elif type_operands == "C":
        ret = getConstant(operands[0])
    elif type_operands == "R":
        complement = registers.get(operands[0]) + complement
    elif type_operands == "RX":
        if operands[1][0] == "@":
            ret = getLabel(operands[1][1:])
        else:
            ret = getConstant(operands[1])
        complement = registers.get(operands[0]) + complement
    elif type_operands == "RR":
        complement = registers.get(operands[0]) + registers.get(operands[1])
    elif type_operands == "RP":
        if operands[1][0] != '[' or operands[1][3] != ']':
            raise SyntaxError(f"Line {line_no}: {mnemonic} operand '{operands[1]}' is not a valid memory request")
        else:
            operands[1] = operands[1][1:3]
        complement = registers.get(operands[0]) + registers.get(operands[1])

    #print(f"Return: {mnemonic} {operands} ({opcode}, {ret}, {complement})")
    return opcode, ret, complement

def preProcLine(line):
    line = line.strip("\n")            # remove new line
    if line.find(";") >= 0:            # -1 if don"t find
        line = line[ :line.find(";") ] # remove comments
    line = line.strip()                # remove leading and trailing whitespace
    line = line.lower()                # lower case
    return line


def parsefile(file):
    if not os.path.isfile(file):
        raise IOError(f"source file {file!r} does not exists.")
        sys.exit(-1)
    with open(file, "r") as f:
        txt = f.readlines()

    addr = 0
    labels = {}
    labelsLineNo = {}
    # First run: find preprocessor directives and labels
    for i, j in enumerate(txt):
        idx = i + 1
        line = preProcLine(j)
        #print("")
        #print(f"-> address   : {addr}")
        #print(f"-> line      : {j.strip(chr(10))}") # chr(10) = \n  <=>  we can"t use backslash inside {} on an f-string
        #print(f"-> line      : {line}")
        # label
        lineColon = line.split(":")
        if len(lineColon) > 1:
            label = lineColon[0].strip()
            line = lineColon[1].strip()
            if label == "":
                raise SyntaxError(f"Line {idx}: Label directive must be followed by ':', for example: 'label:'. Received: {j!r}")
            elif label in labels:
                repeatedLabelDefinition = labelsLineNo[label]
                raise ValueError(f"Line {idx}: Label {label!r} already defined before.\nLine {repeatedLabelDefinition+1}: {txt[repeatedLabelDefinition]!r} <---\nLine {i+1}: {txt[i]!r} <---")
            # append the current addr to this label
            labelsLineNo[label] = i
            labels[label] = addr
        else:
            label = ""
            
        # mnemonics --> find preprocessor directives
        tokens = line.split()
        if len(tokens) > 0:
            mnemonic = tokens[0]
            operands = [x for x in "".join(tokens[1:]).split(",") if x != ""]
            #print(f"--> Tokens   : {tokens}")
            #print(f"--> Mnemonic : {mnemonic}")
            #print(f"--> Operands : {operands}")
            if mnemonic == ".equ":
                if len(operands) < 2:
                    raise SyntaxError(f"Line {idx}: {mnemonic} directive requires 2 arguments")
                labels[ operands[0] ] = int(operands[1], 0)
            elif mnemonic == ".org":
                if len(operands) != 1:
                    raise SyntaxError(f"Line {idx}: {mnemonic} directive requires 1 argument")
                try:
                    jmpAddr = int(operands[0], 0)
                except:
                    raise ValueError(f"Line {idx}: Cannot parse {mnemonic} address {operands[0]}")
                if jmpAddr < addr:
                    raise ValueError(f"Line {idx}: {mnemonic} argument cannot reduce current address {addr}")
                addr = jmpAddr
                # Change label address, label before .org points to next instruction
                if label != "":
                    labels[label] = addr
            elif mnemonic == ".global" or mnemonic == "ld" or mnemonic == "jmp":
                addr += 2
            else: # .byte also...
                addr += 1

    # Labels
    #print(f"Labels: {labels}")

    # Find longest label name
    label_len = 0
    for i in labels.keys():
        label_len = max(label_len, len(i))

    # Second run: write output code
    #print("")
    #print(f"Labels: {labels}")
    #print("")
    code = []
    addr_ndigits = len(str(addr))
    for i, j in enumerate(txt):
        idx = i + 1
        line = preProcLine(j)
        #print("")
        #print(f"-> address   : {addr}")
        #print(f"-> line      : {j.strip(chr(10))}") # chr(10) = \n  <=>  we can"t use backslash inside {} on an f-string
        #print(f"-> line      : {line}")
        # label
        lineColon = line.split(":")
        if len(lineColon) > 1:
            label = lineColon[0].strip()
            line = lineColon[1].strip()
        else:
            label = None

        tokens = line.split()
        if len(tokens) > 0:
            mnemonic = tokens[0]
            operands = [x for x in "".join(tokens[1:]).split(",") if x != ""]

            ret = processAsmLine(idx, mnemonic, operands, labels)
            ref = chr(32)*(label_len+1) if label is None else label + ":" + chr(32)*(label_len-len(label))
            
            if mnemonic == ".equ": # ignore, compiler-time only constant
                pass
            elif mnemonic == ".global":
                code.append((f"{ret[2]}", f"{idx:3}: {ref} {line}"))
                code.append((f"{ret[1]}", f"{idx:3}: {ref} jmp {int(ret[1],2)}"))
            elif mnemonic == ".org": # fill memory until requested address
                while len(code) < int(ret[1], 2):
                    code.append(("00000000", ""))
            elif mnemonic == ".byte":
                # add constant to memory
                code.append((f"{ret[1]}", f"{idx:3}: {ref} {line}"))
            elif mnemonic in ("ld", "jmp"):
                code.append((f"{ret[0]}{ret[2]}", f"{idx:3}: {ref} {line}"))
                code.append((f"{ret[1]}", f"{idx:3}: {ref} {int(ret[1], 2)}"))
            elif mnemonic in ("add", "sub", "and", "or", "xor", "ldr", "str", "inc", "incc", "dec", "decc", "not", "rol", "ror", "lsl", "lsr", "jmpr", "bz", "bnz", "bcs", "bcc", "beq", "bneq", "bgt", "bgez", "blt", "blez", "push", "pop", "halt"):
                code.append((f"{ret[0]}{ret[2]}", f"{idx:3}: {ref} {line}"))
            else:
                print(f"Missing!!! {mnemonic} {ret}")

            #print(f"## Label   :    {label} -- [{ref}]")
            #print(f"## Line {idx:3}: {mnemonic} {operands} returned {ret}")
            #print(f"## Assembly: {code[-1][0]} -- {code[-1][1]}")

    return code


def writeASM(code):
    out = []
    for line in code:
        out.append(f"{line[0]} // {line[1]}")
    return "\n".join(out)


def writeVHDL(file, code):
    out = []
    out.append(f"    -- {file}")
    out.append(f"    signal ram : RAM_t := (")
    for idx, line in enumerate(code):
        out.append(f"        {idx:<3} => \"{line[0]}\", -- {line[1]}")
    out.append(f"        others => (others => '0')")
    out.append(f"    );")
    return "\n".join(out)




asm_doc = """
===== General Assembly Documentation =====

    === Global ===
    
    The first line can/should contain the "global" directive, which tells the kernel where the program execution begins.
    >> .global @label
    When using the global directive, the first two lines of the assembly code are:
    >> jmp @label ; jump to start address

    === Comments ===
    
    Assembly language comment begins with a semicolon (;). It may contain any printable character including blank.
    >>           ; comment without any statement
    >> not Ra    ; negate register A

    === Constants ===
    
    ... write ...
    >> jmp @loop
    >> ld Rx, @constPi

    === Syntax of Assembly Language Statements ===
    
    Assembly language statements are entered one statement per line. Each statement follows the following format:
    >> [label:] mnemonic [operands] [;comment]
"""

def printAssemblyDoc():
    print(asm_doc)
