# Hardware-Accelerator-for-Scaled-Dot-Product-Attention-in-Transformer-Architectures

This document contains the instructions and commands to setup this directory. In the folder tree, several ```Makefile```s are used to 

### Description
Transformers:

Transformers models represent a breakthrough in processing sequential data for large language models and generative artificial intelligence (AI), natural language processing (NLP), machine translation, and sentiment analysis. A. Vaswani et.al propose “Transformer” in their paper “Attention is all you need”. The Transformer overcomes drawbacks of Long Short Term Memory (LSTM) based Recurrent Neural Networks (RNNs) and Convolution Neural Networks (CNNs) as they process in parallel rather than processing sequentially to attend to different parts of the input sequence. 

The transformers employ unique mechanisms such as positional encoding, embedding, and self-attention to enable the creation of sequence relationships. The building blocks of a Transformer are:


### How to compile your design

To compile your design

Change directory to ```run/``` 

```bash
make build-dw
make build
```

All the .sv files in ```rtl/``` will be compiled with this command.

### How to run your design

Run with Modelsim UI 564:
```bash
make debug
```

### Evaluation Testing
To evaluate you design headless/no-gui, change directory to ```run/```
```
make eval
```
This will produce a set of log files that will highlight the results of your design. This should only be ran as a final step before Synthesis

All log files is in the following directory ```run/logs```

All test resutls is in the results log file ```run/logs/RESULTS.log```

All simulation resutls is in the following log file ```run/logs/output.log```

All simulation info is in the following log file ```run/logs/INFO.log```

## Synthesis

Once you have a functional design, you can synthesize it in ```synthesis/```

### Synthesis Command
The following command will synthesize your design with a default clock period of 10 ns
```bash
make all
```
### Clock Period

To run synthesis with a different clock period
```bash
make all CLOCK_PER=<YOUR_CLOCK_PERIOD>
```
For example, the following command will set the target clock period to 4 ns.

```bash
make all CLOCK_PER=10
```

## Appendix

### Directory Rundown

* ```inputs/``` 
  * Contains the .dat files for the input SRAMs used in HW 
* ```HW_specification/```
  * Contains the HW specification document
* ```rtl/```
  * All .v files will be compiled when executing ```make vlog-v``` in ```HW6/run/```
  * A template ```dut.v``` that interfaces with the test fixture is provided
* ```run/```
  * Contains the ```Makefile``` to compile and simulate the design
* ```scripts/```
  * Contains the python script that generates a random input/output
* ```synthesis/```
  * The directory you will use to synthesize your design
  * Synthesis reports will be exported to ```synthesis/reports/```
  * Synthesized netlist will be generated to ```synthesis/gl/```
* ```testbench/```
 

	Positional encoding and embedding:
	The primary target for the Transformer is NLP, which has unique word embedding maps for each word in the sequence to a word vector of d_model size. Word vectors reduce the dimension and improves contextual similarity.
	To retain the order of the sequence, “positional encoding” the input embeddings is performed.
	Self-attention:
	Sometimes called intra-attention, is an attention mechanism relating different positions of a single sequence in order to compute a representation if the sequence. Let’s look at an example: “The animal didn’t cross the street because it was too tired”. The word “it” may refer to animal or to the street. Self-attention mechanisms allow it to associate “it” with “animal”.
	An attention function can be described as mapping a query and a set of key-value pairs to an output, where the query, keys, and values are trainable vectors.
	The “Scaled Dot-Product Attention” is computed by:
Attention(Q,K,V)=softmax((QK^T)/(√d_k ))V
	Multi-Head-Attention (MHA):
	In the transformer, the Attention module repeats its computations multiple times in parallel.
	MHA allows the model to jointly attend to information from different representation subspaces at different positions.
	Performs attention function with multiple 〖head〗_i, each with different, learned linear projections parameter matrices W_i^Q, K_i^K, and V_i^V.
MultiHead(Q,K,V)=Concat(〖head〗_1,〖head〗_2,…,〖head〗_h ) W^O
where 〖head〗_i=Attention(〖QW〗_i^Q,〖KW〗_i^K,〖VW〗_i^V)


Figure 1: Transformer self-attention query, key, value, score and attention connection and matrix dimensions.
Matrix multiplication:
The matrix multiplication is performed on Matrix I (SRAM input) and Matrix W (SRAM project), and the results will be stored in SRAM Result. The equation below, shows the matrix multiplication performed:
[■(Q_1&Q_2&…&Q_16@Q_17&Q_18&…&Q_32@⋮&⋱&⋱&⋮@Q_49&Q_50&…&Q_64 )]=[■(I_1&I_2&…&I_16@I_17&I_18&…&I_32@⋮&⋱&⋱&⋮@I_49&I_50&…&I_64 )] *[■(〖wq〗_1&〖wq〗_17&〖wq〗_33&…&〖wq〗_241@〖wq〗_2&〖wq〗_18&〖wq〗_34&…&〖wq〗_242@〖wq〗_3&〖wq〗_19&〖wq〗_35&…&〖wq〗_243@⋮&⋱&⋱&⋱&⋱@⋮&⋱&⋱&⋱&⋱@〖wq〗_16&〖wq〗_32&…&…&〖wq〗_256 )] 	(Eq: 1)
As regular matrix multiplication, you will multiply and accumulate each row element of matrix I with column elements of matrix W. The expression below shows the example computation:
Q_1= (I_1*〖wq〗_1 )+(I_2*〖wq〗_2 )+(I_3*〖wq〗_3 )+⋯+(I_16*〖wq〗_16 )
Q_2= (I_1*〖wq〗_17 )+(I_2*〖wq〗_18 )+(I_3*〖wq〗_19 )+⋯+(I_4*〖wq〗_32 )  ⋯
Q_17= (I_17*〖wq〗_1 )+(I_18*〖wq〗_2 )+(I_19*〖wq〗_3 )+⋯+(I_32*〖wq〗_16 )
Q_18= (I_17*〖wq〗_17 )+(I_18*〖wq〗_18 )+(I_19*〖wq〗_19 )+⋯+(I_32*〖wq〗_32 )  ⋯
Q_63= (I_49*〖wq〗_241 )+(I_50*〖wq〗_242 )+(I_51*〖wq〗_243 )+⋯+(I_64*〖wq〗_256 )

 
ECE464 project:
The 464 project will realize the 〖QK〗^T part of the self-attention equation. This involves multiple matrix multiplication operations to obtain the results. The inputs and weight parameters are loaded by the testbench in “sram_input” and “sram_weight”. The results are expected to be written by the DUT in “sram_result”. Refer to the “SRAM contents mapping” section for the corresponding mapping schemes of different parameters.
	Calculating the query (Q) and key (K) matrices.
	Query (Q) is obtained by multiplying input embedding (I) with weight matrices (W^Q).
	Q=I*W^Q
	Key (K) is obtained by multiplying input embedding (I) with weight matrices (W^K).
	K=I*W^K
 
Figure 2: Calculation of Query and Key matrices by multiplying Input embedding with corresponding weight parameters (W^Q,W^K).
	Compute the score matrix.
	Transpose the Key matrix from the previous step to obtain K^T.
	Multiply Query (Q) with Key transpose (K^T).
	Score=QK^T
 
ECE564 project:
The 564 project will realize the “Scaled Dot-Product Attention” [((QK^T)/(√d_k ))V].
	Calculating the query (Q), key (K), and value (V) matrices.
	Query (Q) is obtained by multiplying input embedding (I) with weight matrices (W^Q).
	Q=I*W^Q
	Key (K) is obtained by multiplying input embedding (I) with weight matrices (W^K).
	K=I*W^K
	Value (V) is obtained by multiplying input embedding (I) with weight matrices (W^V).
	V=I*W^V
	Compute the score matrix (S).
	Transpose the Key matrix from the previous step to obtain K^T.
	Multiply Query (Q) with Key transpose (K^T).
	S=QK^T
	Compute the scaled dot-product attention (Z).
	Multiply the score (S) with the value (V).
	Z=S*V





 
System signals: 
	reset_n is used to reset the logic into a known state, 
	clk is used to drive the flip-flop logic in the design.

Control signals: 
	dut_valid: used as part of a hand shack between the test fixture and the dut. Valid is used to signal that a valid input can be computed from the SRAM.
	dut_ready: used to signal that the dut is ready to receive new input from the SRAM. 
	Together these two signals tell the test fixture the state of the dut. So, the dut should assert dut_ready on reset and wait for the dut_valid to be asserted. 
	Once dut_valid is asserted by the test fixture, the dut should set dut_ready to low and can start reading from the SRAM. 
	Dut should hold the dut_ready low until it has populated the result values in the SRAM. Once the results are stored in the SRAM the dut_ready will be asserted high, signaling that the result is valid, and is ready to be read from SRAM. Fig 2 shows the expected behavior.

      
Fig 2. Test fixture and DUT handshake behavior

 
SRAM contents mapping:
The SRAM holds the 32-bit data in each address. The table below shows the memory mapping of various SRAM addresses. The color schemes corresponding to Equation 1. The input SRAM’s contains the input matrix dimension at address 12’h00, while the matrix data from 12’h01 onwards. 
SRAM input: Address	SRAM input: Content [31:0]
12’h00	[31:16] – Number of matrix A rows, [15:0] – Number of matrix A columns
12’h01	I1
12’h02	I2
.	.
.	.
12’h40	I64

SRAM weight: Address	SRAM weight: Content [31:0]
12’h00	[31:16] – Number of matrix B rows, [15:0] – Number of matrix B columns
12’h01	wq1
12’h02	wq2
.	.
.	.
12’h100	wq256
12’h101	wk1
12’h102	wk2
.	.
.	.
12’h200	wk256
12’h201	wv1
12’h202	wv2
.	.
.	.
12’h300	wv256


SRAM Result: Address	SRAM Result: Content [31:0]
12’h00	Q1
12’h01	Q2
.	.
.	.
12’h3F	Q64
12’h40	K1
12’h41	K2
.	.
.	.
12’h7F	K64
12’h80	V1
12’h81	V2
.	.
.	.
12’hBF	V64
12’hC0	S1
12’hC1	S2
.	.
.	.
12’hCF	S16
12’hD0	Z1
12’hD1	Z2
.	.
.	.
12’h10F	Z64


 
SRAM: 
 
Fig 3. SRAM interface ports

The SRAM is word addressable and has a one cycle delay between address and data. When writing to the SRAM, you would have to set the “write_enable” to high. The SRAM will write the data in the next cycle. “read_write_select” is not used for this implementation.

  
Fig 4. SRAM timing behavior

As shown in the Fig 4, since “write_enable” is set to low when A5 and D5 is on the write bus, D5 will not be written to the SRAM. Also, because “read_write_select” is set to high, the read request for A6 will not be valid. 

Note that the SRAM cannot handle consecutive read after write (RAW) to the same address (shown as A11 and D11 in the timing diagram). You would have to either manage the timing of your access or write the data forwarding mechanism yourself. As long as the read and write address are different, the request can be pipelined.


Important Notes:
	Please read the README and look at the dut.sv/testbench.sv file.
	Design should not have any major/minor synthesis errors pointed out in the Standard Class Tutorial (Appendix C). This includes but is not limited to latches, wired-OR, combination feedback, etc. 
 
Design, verify, synthesize a module that meets these specifications.  Use at least one coding feature unique to System Verilog. 


Submission Instruction:
	Project Verilog and synthesis files. Submitted electronically on the date indicated in the class schedule. Please turn in the following: 
	All Verilog files AS ONE FILE in submission.
	Zipped modelsim simulation results file showing correct functionality. Logs from ‘/run/logs/*.log’
	Synopsys view_command.log file from complete synthesis run 
	Project Report. Complete report to be turned in electronically with project files. It must follow the format attached. There is a 10% penalty for not following the format. 
	DUT ONLY submission. Submit your dut.sv file without any folders or zip files, just the .sv file on its own to the DUT ONLY project submission link on Moodle.
 
[50 points] 

