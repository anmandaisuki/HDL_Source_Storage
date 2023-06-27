ddr3_model.sv : ddr3メモリシュミレーションモデル。428行目の$fopen();にあるように、特定ファイルをロードすることができる。ファイルの記述方法はシンプル。address txt dataのフォーマットで記載する。
		// Memory Storageに'ifdef MAX_MEMとあるので、MAX_MEMとmem_initをdefineしないと、$fopen()が有効化されない。

メモリファイル例: データ幅64bit。DATA1とかの記述は特に意味はない。16進数記述なので、64bit幅なら1行あたりのアドレスは8byteで、16個のアルファベットになる。
00010000 DATA1 1020304050607080
00010008 DATA 8070605040302010

メモリファイル例:データ幅32bit
00010000 DATA 10203040
00010004 aaaa FFFFFFFF

ddr3_model.svを使うためにすること
	1. 'define MAX_MEMと'define mem_initをどこかに記載。
	2.読み込み用ファイルmem_init.txtをsimフォルダにaddする。

ddr3_model.svの中身は一緒でDRAMによる違いはddr3_model_parateters.vhファイルの中身で記載。 `include "ddr3_model_parameters.vh"でパラメータimportしてる。
	ddr3_model_parameters.vhを書き換える必要はなく、ddr3_model.svの中で適切にDDRの種類について、'defineすればいい。
	ddr3_parameters.vhの中身は、いろんなDDRのパラメータが定義されており、'ifdefでDDRごとに分けてある。

	どうやって'defineをすればいいかわからないときは、migでメモリを選んで、そのexample designで自動生成されるddr3_model.svのを使えばいい？
	ddr3_model_parameters.vhはprojectにaddしておく。

DDRの'defineについて（基本、以下の３種類defineしておけばいい）
	`define x2Gb	// DRAMの容量(bit)
	`define sg15E	// speed grade 
	`define x16	// データ幅。 
	上の３つ大体すべて型番見ればわかる。
	ex) MT41K128M16JT-125 
		128Meg*16 bit  => 'define x2Gb
		speed grade 125 => 'define sg125
		data width      => 'define x16

'defineによって、ddr3_modelの端子幅(addr,dqとか)やバースト長さを変えてる。bank数とかもDRAMによって違うけど、'defineで決定するparameterでその差を埋めている。
	
895行目のメモリが実際のDDR3のメモリの定義だと思う。simulationでDRAMの中身が実際に思い通りに動いているか確認したいときはmemoryやその近辺で定義されているaddressとかチェックしてば良いかも。

メモリファイル(mem_init.txt)はカレントディレクトリにおいておく。
	get_property DIRECTORY [current_project]
	↑のコマンドをtcl consolenに入力すれば、カレントディレクトリを入手できる。

DDRの型番(Micron)について補足
	MT41xxx      : xxxがA->Zにいくにつれて、DDR3シリーズ内で新しくなっていく。DDR4はMT40シリーズ
	MT41J(DDR3)  :Vddが1.5Vだけ。
	MT41K(DDR3-L):Vddが1.5Vでも1.35Vでもいけるやつ。

vivadoのbehaviorシミュレーションについて
	init_calib_completeがHになるまで、150usくらいかかる。
	memoryのindexはアドレスと一致してないかも。
	cke,cs_n,ras_n,cas_n,we_nがコマンド(read/writeとか)の役割を担う。cs_nはチップセレクトなので、DDR複数接続されているときに使われる。有効なDDRはLになる。
	cs_nがLのときにread/writeのコマンドが入っていると考えられる。
	DDR側ではADDRとDQの入力タイミング違う。コマンドの入力と同じタイミングでアドレスが入力されて、その４クロックあとくらいにデータが８個（バースト）くらい連続で転送される。
