//BIN2BCD.v
//  BIN2BCD
//
// binary to BCD converter (flash: 1 clock dly but huge and slow)
// input DAT_i/27   : binary
// output QQ        : BCD 8 digit
//
//170506sa          :calc stop by CTR
//170504th          :add normal shift register mode/non millionaire
//170424m           :add generate begin bleas
//170422s           :by @mangakoji


// bin2BCD core 
// calc 2 BCD data DAT_A_i, DAT_B_i addition
// if DAT_A_i+ DAT_B_i and over 10 , cyo is H
//   and output yy_o (A+B)-10
module BCD_ADDER(
      input [ 3 :0] DAT_A_i //0 upto 9
    , input [ 3 :0] DAT_B_i //0 upto 9
    , input         CYI_i
    , output[ 3 :0] yy_o    //0 upto 9
    , output        cyo_o
) ;
    wire    [4:0] DAT_add ;
    assign DAT_add = {1'b0 , DAT_A_i} + {1'b0 , DAT_B_i} + {4'b0,CYI_i} ;
    assign cyo_o = DAT_add >= 5'd10 ;
    assign yy_o = (cyo_o) ? (DAT_add - 5'd10) : DAT_add[3:0] ;
endmodule



// main part
// this is millionaire codeing
module BIN2BCD_MILLIONAIRE (
      input                 CK_i
    , input tri0            XARST_i
    , input tri1            EN_CK_i
    , input tri0    [26:0]  DAT_i
    , output        [31:0]  QQ_o
) ;
    // every DAT bit is H, add those SEED every digit
    localparam [32*10*4-1:0] C_BIT_SEED = {
            40'h0000000001
          , 40'h0000000002
          , 40'h0000000004
          , 40'h0000000008
          , 40'h0000000016
          , 40'h0000000032
          , 40'h0000000064
          , 40'h0000000128
          , 40'h0000000256
          , 40'h0000000512
          , 40'h0000001024
          , 40'h0000002048
          , 40'h0000004096
          , 40'h0000008192
          , 40'h0000016384
          , 40'h0000032768
          , 40'h0000065536
          , 40'h0000131072
          , 40'h0000262144
          , 40'h0000524288
          , 40'h0001048576
          , 40'h0002097152
          , 40'h0004194304
          , 40'h0008388608
          , 40'h0016777216
          , 40'h0033554432
          , 40'h0067108864
          , 40'h0134217728
          , 40'h0268435456
          , 40'h0536870912
          , 40'h1073741824
          , 40'h2147483648
    } ;

    // instance BCD adder
    // bit_rayer(bit) digit
    // show chart BIN2BDC.bdf
    wire    [3:0]   yy  [0:31][0:9] ;
    wire            cy  [0:31][0:9] ;
    genvar g_bit ;
    genvar g_digit ;
    generate 
    for (g_bit=0; g_bit<32; g_bit=g_bit+1) begin:gen_bit
        for(g_digit=0; g_digit<10; g_digit=g_digit+1) begin: gen_digit
            BCD_ADDER BCD_ADDER(
                  .DAT_A_i  ( 
                    (g_bit==0)? 
                        'd0 
                    : 
                        yy[g_bit-1][g_digit]
                  )
                , .DAT_B_i  ( 
                    {4{DAT_i[g_bit]}} 
                    & 
                    C_BIT_SEED[((31-g_bit)*40)+4*g_digit +:4]  
                )
                , .CYI_i    (
                     (g_digit==0) ? 
                        'd0 
                    : 
                        cy[g_bit][g_digit-1]
                )
                , .yy_o     ( yy[g_bit][g_digit]        )
                , .cyo_o    ( cy[g_bit][g_digit]        )
            ) ;
        end
    end
    endgenerate 


    //simply output latch
    reg [39:0] QQ ;
    generate 
        for(g_digit=0; g_digit<10; g_digit=g_digit+1) begin : gen_digit
            always @(posedge CK_i or negedge XARST_i)
                if ( ~ XARST_i)
                    QQ[4*g_digit +:4] <= 4'd0 ;
                else if ( EN_CK_i )
                    QQ[4*g_digit +:4] <=  yy[31][g_digit] ;
        end
    endgenerate
    assign QQ_o = QQ ;
endmodule


// BCD module 
// made of shift register
// in 1clock( & SFL1_i==1)
// calc new_X = last_X * 2 + cy
module BCD_BY2_ADDCY (
      input             CK_i
    , input tri1        XARST_i
    , input tri1        EN_CK_i
    , input tri0        RST_i
    , input tri0        SFL1_i
    , input tri0        cyi_i
    , output    [ 3 :0] BCD_o
    , output            cyo_o

) ;
    wire[ 3 :0] added   ;
    wire        cyo     ;
    reg [ 3 :0] BCD ;
    assign added = BCD + 4'h3 ;
    assign cyo = added[ 3 ] ;
    always @ (posedge CK_i or negedge XARST_i)
        if ( ~ XARST_i)
            BCD <= 4'b0 ;
        else if ( EN_CK_i )begin
            if ( RST_i)
                BCD <= 4'h0 ;
            else if ( SFL1_i )
                BCD <= ( cyo ) ? 
                        {added[2:0] , cyi_i}
                    :
                        {BCD[2:0] , cyi_i}
                ;
        end
    assign BCD_o = BCD ;
    assign cyo_o = cyo ;
endmodule



// this is  non_Millionaire code
//  calc by shift register 
//   spend in->out 27+2 ck 
//
module BIN2BCD_SHIFT #(
    parameter C_WO_LATCH = 0
)(
      input                 CK_i
    , input   tri1          XARST_i
    , input   tri1          EN_CK_i
    , input   tri0  [26:0]  DAT_i
    , input   tri0          REQ_i
    , output        [31:0]  QQ_o
    , output                DONE_o
) ;
    // ctl part
    reg [ 5 :0] CTR     ;
    reg [ 1 :0] CY_D    ;
    wire        cy ;
    assign cy = CTR == 6'b01_1111 ;
    always @ (posedge CK_i or negedge XARST_i)
        if ( ~ XARST_i)
            CTR <= 6'h3F ;
        else if ( EN_CK_i )
            if ( REQ_i )
                CTR <= {5{1'b1}} & (~(5'd27-1)) ;
            else if ( ~ (&(CTR)) )
                CTR <= CTR + 6'd1 ;
    always @ (posedge CK_i or negedge XARST_i)
        if ( ~ XARST_i)
            CY_D <= 2'b00 ;
        else if ( EN_CK_i )
            CY_D <= {CY_D[0] , cy} ;

    // main part
    reg [26:0]  BIN_DAT_D ;
    always @ (posedge CK_i or negedge XARST_i)
        if ( ~ XARST_i)
            BIN_DAT_D <= 27'b0 ;
        else if ( EN_CK_i )
            if ( REQ_i )
                BIN_DAT_D <= DAT_i ;
            else
                BIN_DAT_D <= {BIN_DAT_D[25:0] , 1'b0} ;
        
    wire[ 3 :0] BCD [ 7 :0]     ;
    wire[ 7 :0] cys             ;
    genvar g_idx ;  
    generate 
        for (g_idx=0; g_idx<8; g_idx=g_idx+1) begin:gen_BCD
            BCD_BY2_ADDCY BCD_BY2_ADDCY (
                  .CK_i     ( CK_i          )
                , .XARST_i  ( XARST_i       )
                , .EN_CK_i  ( EN_CK_i       )
                , .RST_i    ( REQ_i         )
                , .SFL1_i   ( ~ CTR[5]      )
                , .cyi_i    ( (g_idx==0) ? BIN_DAT_D[26] : cys[g_idx-1] )
                , .BCD_o    ( BCD   [ g_idx ]   )
                , .cyo_o    ( cys   [ g_idx ]   )
            ) ;
        end
    endgenerate
    
    reg [31 :0]  QQ ;
    generate 
        if (C_WO_LATCH) begin
            assign QQ_o = {
                  BCD   [ 7 ]
                , BCD   [ 6 ]
                , BCD   [ 5 ]
                , BCD   [ 4 ]
                , BCD   [ 3 ]
                , BCD   [ 2 ]
                , BCD   [ 1 ]
                , BCD   [ 0 ]
            } ;
            assign DONE_o = CY_D[0] ;
        end else begin
            always @ (posedge CK_i or negedge XARST_i)
                if ( ~ XARST_i )
                    QQ <= 32'd0 ;
                else if ( EN_CK_i   )
                    if ( CY_D[0]    )
                        QQ <= {
                          BCD   [ 7 ]
                        , BCD   [ 6 ]
                        , BCD   [ 5 ]
                        , BCD   [ 4 ]
                        , BCD   [ 3 ]
                        , BCD   [ 2 ]
                        , BCD   [ 1 ]
                        , BCD   [ 0 ]
                    } ;
            assign QQ_o = QQ ;
            assign DONE_o = CY_D [1] ;
        end
    endgenerate
endmodule


module BIN2BCD #(
      parameter C_MILLIONAIRE = 0   //1:Millionaire code  0:normal shift regs
    , parameter C_WO_LATCH   = 0    //0:BCD latch, increse 32FF, 1:less FF but
)(
      input                 CK_i
    , input   tri1          XARST_i
    , input   tri1          EN_CK_i
    , input   tri0  [26:0]  DAT_i
    , input   tri0          REQ_i
    , output        [31:0]  QQ_o
    , output                DONE_o
) ;
    generate 
        if (C_MILLIONAIRE) begin: gen_MILLIONAIRE
            BIN2BCD_MILLIONAIRE BIN2BCD_MILLIONAIRE (
                  .CK_i     ( CK_i     )
                , .XARST_i  ( XARST_i  )
                , .EN_CK_i  ( EN_CK_i  )
                , .DAT_i    ( DAT_i    )
                , .QQ_o     ( QQ_o     )
            ) ;
        end else begin :gen_NON_MILLIONAIRE
            BIN2BCD_SHIFT #(
                .C_WO_LATCH ( C_WO_LATCH )
            )BIN2BCD_SHIFT (
                  .CK_i     ( CK_i      )
                , .XARST_i  ( XARST_i   )
                , .EN_CK_i  ( EN_CK_i   )
                , .DAT_i    ( DAT_i     )
                , .REQ_i    ( REQ_i     )
                , .QQ_o     ( QQ_o      )
                , .DONE_o   ( DONE_o    )
            ) ;
        end
    endgenerate
endmodule


//example  instanse for mesure fmax
module BIN2BCD_top(
      input         CK_i
    , input         XARST_i
    , input         EN_CK_i
    , input [26:0]  DAT_i
    , input         REQ_i
    , output[31:0]  QQ_o
    , output        DONE_o
) ;
    reg [26:0]  DAT ;
    always @(posedge CK_i or negedge XARST_i)
        if ( ~ XARST_i)
            DAT <= 27'd0 ;
        else if ( EN_CK_i )
            DAT <= DAT_i ;
    BIN2BCD #(
         .C_MILLIONAIRE( 0 )        //non_millionaire mode=0
    )u_BIN2BCD(
          .CK_i     ( CK_i      )
        , .XARST_i  ( XARST_i   )
        , .EN_CK_i  ( EN_CK_i   )
        , .DAT_i    ( DAT       )
        , .REQ_i    ( REQ_i     )
        , .QQ_o     ( QQ_o      )
        , .DONE_o   ( DONE_o    )
    ) ;
endmodule



// test bentch random input compair
module TB_BIN2BCD #(
    parameter C_C = 10
)(
) ;
    reg CK ;
    initial begin
        CK <= 1'b1 ;
        forever begin
            #(C_C/2.0)
                CK <= ~ CK ;
        end
    end
    reg XARST ;
    initial begin
        XARST <= 1'b1 ;
        #(0.1 * C_C)
            XARST <= 1'b0 ;
        #(3.1 * C_C)
            XARST <= 1'b1 ;
    end
 
 
    integer rand_reg    = 1 ;
    integer idx ;
    reg [26:0]  DAT ;
    reg [ 3:0] DIGIT    [0:7]  ;
    reg [ 3:0] DIGIT_D  [0:7]  ;
    reg [ 3:0] DIGIT_DD [0:7]  ;
    reg [ 3:0] DIGIT_DDD[0:7]  ;
    wire[31:0]  QQ      ;
    wire    [3:0]   QQ_DIGIT [0:7] ;
    reg [7:0]   CMP ;
    reg         CMP_TOTAL   ;
    reg         REQ         ;
    wire        DONE        ;
    initial begin
        rand_reg = 1 ;
        REQ <= 1'b0 ;
        for (idx=0;idx<8; idx=idx+1) begin
            DIGIT[idx] =  'd0 ;
            CMP[idx] <= 1'b1 ;
        end 
        repeat (10) @(posedge CK) ;
        repeat( 10000 ) begin
            DAT = $random(rand_reg) ;
//            DAT = rand_reg ;
//            rand_reg = rand_reg + 1 ;
            REQ <= 1'b1 ;
            @(posedge CK) ;
            REQ <= 1'b0 ;
            while( ~ DONE )
                @(posedge CK) ;
            for (idx=0;idx<8; idx=idx+1) begin
                DIGIT[idx] =  (DAT/(10**idx)) % 10 ;
                CMP[idx] = (QQ_DIGIT[idx] == DIGIT[idx]) ;
                CMP_TOTAL = & CMP ;
            end
            @ (posedge CK) ;
            
        end
        $stop ;
    end 
    
    always @(posedge CK or negedge XARST)
        if (~ XARST) begin
            for (idx=0;idx<10; idx=idx+1) begin
                DIGIT_D[idx] <=  'd0 ;
                DIGIT_DD[idx] <=  'd0 ;
                DIGIT_DDD[idx] <=  'd0 ;
            end
        end else if ( DONE ) begin
            for (idx=0;idx<10; idx=idx+1) begin
                DIGIT_D[idx]    <= DIGIT[idx] ;
                DIGIT_DD[idx]   <= DIGIT_D[idx] ;
                DIGIT_DDD[idx]  <= DIGIT_DD[idx] ;
            end
        end


    BIN2BCD #(
        .C_MILLIONAIRE ( 0 )
    )u_BIN2BCD(
          .CK_i     ( CK        )
        , .XARST_i  ( XARST     )
        , .EN_CK_i  ( 1'b1      )
        , .DAT_i    ( DAT       )
        , .REQ_i    ( REQ       )
        , .QQ_o     ( QQ        )
        , .DONE_o   ( DONE      )
    ) ;
    genvar g_idx ;
    generate
        for (g_idx=0;g_idx<8; g_idx=g_idx+1) begin :gen_digit
            assign QQ_DIGIT[g_idx] = QQ[g_idx*4 +:4] ;
        end
    endgenerate
endmodule
