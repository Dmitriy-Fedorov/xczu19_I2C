import os, re

path = "."

files = os.listdir(path)
files = [f for f in files if f[-2:] == ".h"]


if len(files) == 1:
    fname = files[0]
elif len(files) > 1:
    for i, file in enumerate(files):
        print(i, file)
    num = input("Select file...\n:")
    fname = files[int(num)]


if len(files) >= 1:
    program = ""
    info = "/*\n"
    with open(f"{path}\\{fname}", "r") as f:
        old_page = ""
        i = 0
        k = 0
        
        for line in f.readlines():
            line = line.strip()
            if "* Outputs:" in line:
                k += 1
            if k > 0 and k < 22:
                info += f" {line}\n"
                k+=1

            res = re.search(r"\{(.+?)\}", line)
            if res is not None:
                res_str = res.group(1).strip()
                if res_str == "0x000B, 0x74":
                    continue
                page = res_str[2:4]
                reg = res_str[4:6]
                val = res_str[-2:]
                if old_page != page:
                    program += f"    //{i}: {res_str[:7]}{res_str[8:]}\n"
                    program += f"    addr[{i}] <= 8'h01;    //page change \n"
                    program += f"    data[{i}] <= 8'h{page};    //page change \n"
                    program += f"    addr[{i+1}] <= 8'h{reg}; \n"
                    program += f"    data[{i+1}] <= 8'h{val}; \n"
                    i += 2
                else:
                    program += f"    //{i}: {res_str[:7]}{res_str[8:]}\n" 
                    program += f"    addr[{i}] <= 8'h{reg}; \n"
                    program += f"    data[{i}] <= 8'h{val}; \n"
                    i += 1
                old_page = page

    info += " */" 
    program = f"""`timescale 1ns / 1ps

module ROM(
//    input wire clk,
    input wire[8:0] i,
    output wire[7:0] addr_i,
    output wire[7:0] data_i
    );
    
reg[7:0] addr[0:{i-1}];
reg[7:0] data[0:{i-1}];

assign addr_i = i < {i} ? addr[i] : addr[{i-1}];
assign data_i = i < {i} ? data[i] : data[{i-1}];

{info}

initial
begin
""" + program

    program += \
"""
end

endmodule
"""          

    with open(f"{path}\\ROM.v", "w") as f:
        f.write(program)  

else:
    print("Not found")
