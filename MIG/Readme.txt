MIGで作られるモジュールはそれだけだとかなり使いづらい。
migで作られたmoduleのインターフェイス見てもらえばわかるけど、PL側のポートが若干複雑。（DDR3側の物理ポートは単純にDDR3ICチップのピンと同じ）
例えば、DDRの書き込みには、migモジュールにアドレス入力（ランク、バンク、row,column）やイネーブル信号などを送る必要あり。
またこのときにmigからのrdy信号とかをチェックしないといけない。

そこで、すごい簡単にはできないけど、少し簡易化する。
クロック信号やリセット信号を除いて20本あった信号を10本にしてる

mig_ui.v(mig_userinterface)は大体の信号をそのまま通過させてるだけ。

DRAMは大概バーストモードで動作する。
バーストモードは一回のアドレス入力で複数アドレスを読み出し/書き出しすること。一回一回アドレス入力してたら時間めっちゃかかるから。
バースト長8なら、一つのアドレス送信で8個のデータを送る。メモリによってはバースト長も設定できる。
バーストされる単位は1byteかもしれないし、2byte,4byteかもしれない。これはセル（row,columnで指定されるデータ単位）が何bit保存できるかによる。ビット幅とも言う。
たいがいメモリの型番見ればビット幅はわかる。MT41K128M16JTなら16bit幅で128Megのデータ深さがあるので、16bit*128Megで約2Gbit(256Mbyte)になる。
128Megの中身の詳細(バンクの構成とか)はデータシートを見るとわかる。。MT41K128M16JTでは、16Megのバンクが８個ある。
cellが2byteでバースト長８なら、一つのアドレスで2byte*8=16byte書き込み/読み出しが行われる。
バースト長さが８のとき、基本的に8アドレスごとでのデータのやり取りになるので、2^3=8より、アドレスの下位3bitはあまり意味がない。ただし転送されるデータの順番が若干異なるので注意。
書き込みに関しては、下位３bitはまじで関係ない。addrコマンドが28bitのとき、転送アドレスはaddr[27:3]できまり、そこから８アドレス分転送する。
読み出し時は若干順番が変わる。


migのuser側の信号の説明（全部で10ポート）
	app_cmd : 書き込みか読み出しかの指定。	3'b000で書き込み、3'b001で読み出し。なんで3ビットかは不明。
	app_en : app_cmdが有効化どうか。app_cmdを送るときにapp_enはHでないといけない。
	app_rdy:mig側がapp_cmdを受け入れることができる状態かどうか。つまりコマンドを送るには、app_rdyがHのときにapp_enをHにして、コマンドを送る必要あり。
	app_addr:rank+bank+row address+column adress。MIG生成するタイミングでランク数やバンク数などがメモリによって異なるため、使用メモリやメモリチップ数によって、app_addrのビット幅変わる。

	app_wdf_rdy: migが書き込みデータの受付可能かどうか。つまり書き込み時にはapp_rdyだけでなくapp_wdf_rdyがHかどうか確認する必要あり。
	app_wdf_wren : app_wdf_rdyがHのときにapp_wdf_wrenをHにして、app_wdf_dataをmigに送信する。 
	app_wdf_data :　16byteで128bit幅。app_wdf_maskでマスクできる。(書き込みを行わない)
	app_wdf_mask : app_wdf_dataのマスク。16bit幅で例えばapp_wdf_mask[0]=1なら、app_wdf_data[7:0]が無視される。

	app_rd_data_valid : migからの出力でapp_rd_dataが有効かどうか。
	app_rd_data : migからの出力で、読み出しデータ。bit幅はメモリのデータ幅*バースト長さでメモリで決定する。16bit幅でバースト長さ8のメモリなら128bit幅。

クロックについて
	migでの設定で4箇所選ぶ場所ある。1.clock period : migの動作周波数。	2.Input clock period : migに入力するクロック周波数。sys_clkに入力するclkの周波数。このクロックからclock periodの周波数を内部PLLで作る。	
	3. system clock : input clock period をどこから取るかで、内部生成する場合はnobuffer. 	4. reference clock : input clock　period以外に参照用に200MHzのクロックが必要でどこから取るか。
	つまり実際に用意しなくてはいけないクロックは200MHz(参照用)とinput clock（mig動作周波数を作るためのクロック）。migの動作クロックは直接は入力せずsys_clkに入力して、内部で生成する。
	migが出力するui_clkはユーザーインターフェイス用に出力してくれてるけど、このままだと使いづらいので、fifo_asyncとclk_wizardを使用して、周波数変換と非同期データ交換を行う。
	mig_ui_clkは1のclock period(migの動作周波数)の1/4がデフォルトになっている。動作周波数を400MHzとしたら、100MHzが出力される。(1/4を変えられるかは不明。)
	
dram.vについて
	おそらくreadとwrite両方同時にできないようになってる？!dout_afifo1_wenのときに、dram_renがアサートされるようになってる。
	fifo_syncでdramからreadしたデータを一時的に保存してる。read_en信号とread_valid信号のズレをある程度干渉する。ただこれによって、レイテンシとか生じる可能性はある。

adc_dram_interface.vについて
	i_adc_data_en信号はそのときにデシリアライズされた信号に対してなので、実際のADCから出ている信号と若干ずれてる。i_adc_data_enはある程度、連続でHにすることを想定してる。
	基本ストリーム動作を想定しているので、アドレスとかの指定は内部で完結するようにして、インターフェイス簡易化。
	用途としては一旦、ボード上のDRAMに格納したのを、外部（ROMやPCのRAMとか）に飛ばす。

AXIとDRAMのアドレスについて
	AXIのアドレスは常に8bit(1byte)ごと。DRAMのアドレスはセルの大きさによる。セルが16bitの場合、2byteごとに1つのアドレスとなる。
	ARSIZEはAXIバスよりも小さくなる。ARSIZEが32bitでAXIバス幅が64bitかもしれない？この場合１クロックで２データ送れることになる。

動作条件
	APP_DATA_WIDTH > AXI_DATA_WIDTHかつAPP_DATA_WIDTH/AXI_DATA_WIDTHが割り切れる条件でないといけない。ただ、おそらくだいたいの場合大丈夫。
	おそらく普通APP_DATA_WIDTHは128bitでAXI_DATA_WIDTHは16,32,64,128bitだから。


