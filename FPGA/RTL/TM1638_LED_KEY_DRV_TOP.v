// TM1638_LED_KEY_DRV_TOP.v
//      TM1638_LED_KEY_DRV_TOP()
// 
// TM1638 LED KEY BOARD using driver
//    demo top on CQ MAX10-FB(Altera MAX10:10M08SAE144C8G)
//
// test in aitendo board vvv this
// http://www.aitendo.com/product/12887
// maybe move on many boards used TM1638
//
//
// twitter:@manga_koji
// hatena: id:mangakoji http://mangakoji.hatenablog.com/
// GitHub :@mangakoji
//
//170506s     :BIN2BCD append , append check circuit 
//170501m  002 :1st. compile is passed , and debug start
//170430u   001 :1st. cp from VR_LOC_DET_TOP.v
//170408s   004:append SOUNDER
//          003 :append SERVO
//          002 :enlarge VR_LOC 00-FF , debug LED7SEG
//          001 :W MSEQ blanched , P-N combine
//170407f   001 :W MSEQ PN conbine
//170406r   001 throw : LOGIANA_NTSC
//170328tu  001 throw : 
//170326u   001 :new for VR_LOC_DET_OP
//170323r   001 :retruct ORGAN
//170320m   002 :start ORGOLE
//170320m   001 :mv to CQMAX10 
//151220su      :mod sound ck 192 -> 144MHz
//               1st
//

module TM1638_LED_KEY_DRV_TOP(
      input     CK48M_i     //27
    , input     XPSW_i      //123
    , output    XLED_R_o   //120
    , output    XLED_G_o   //122
    , output    XLED_B_o   //121
    // CN1
    , inout     P62
    , inout     P61
    , inout     P60
    , inout     P59
    , inout     P58
    , inout     P57
    , inout     P56
    , inout     P55
    , inout     P52
    , inout     P50
    , inout     P48
    , inout     P47
    , inout     P46
    , inout     P45
    , inout     P44
    , inout     P43
    , inout     P41
    , inout     P39
    , inout     P38
    // CN2
    , inout     P124
    , inout     P127
    , inout     P130
    , inout     P131
    , inout     P132
    , inout     P134
    , inout     P135
    , inout     P140
    , inout     P141
//    , inout     P3 //analog AD pin
    , inout     P6
    , inout     P7
    , inout     P8
    , inout     P10
    , inout     P11
    , inout     P12
    , inout     P13
    , inout     P14
    , inout     P17

) ;
    function integer log2;
        input integer value ;
    begin
        value = value-1;
        for (log2=0; value>0; log2=log2+1)
            value = value>>1;
    end endfunction
    parameter C_FCK = 48_000_000 ;


    // start
    wire            XARST           ;
    wire            CK196M          ;
    wire            CK              ;
    assign CK = CK48M_i ;
    PLL u_PLL(
              .areset       ( 1'b0          )
            , .inclk0       ( CK48M_i       )
            , .c0           ( CK196M        )
            , .locked       ( XARST         )
    ) ;
    localparam  [63:0] C_PULSE_NS ={
           8'b1
        ,  8'd3
        ,  8'd5
        ,  8'd7
        ,  8'd9
        , 8'd11
        , 8'd13
        , 8'd15 
    };
    localparam  [31:0] C_INCDATS  ={
            4'h1
          , 4'hB
          , 4'hD
          , 4'h7
          , 4'h9
          , 4'h3
          , 4'h5
          , 4'hF
    } ;
    wire [ 7 :0]    EN_CKS          ;
    reg  [ 3 :0]    TIM_CTRS [ 7 :0];
    reg  [ 7 :0]    LEDS            ;
    wire [ 7 :0]     KEYS           ;
    generate
        genvar g_idx ;
        for (g_idx=0 ; g_idx<8 ; g_idx=g_idx+1)begin :gen_timectr
            SUBREG_TIM_DIV #(
                .C_PERIOD_W( log2('d180_000_000_0) )
            )SUBREG_TIM_DIV(
                  .CK_i     ( CK                    )
                , .XARST_i  ( XARST                 )
                , .RST_i    ( KEYS[1]               )
                , .PERIOD_i ( 'd180_000_000          )
                , .PULSE_N_i( C_PULSE_NS[ 8*g_idx +:8]   )
                , .EN_CK_o  ( EN_CKS    [ g_idx ]   )
            ) ;
            always @ (posedge CK or negedge XARST)
                if ( ~ XARST)
                    TIM_CTRS[g_idx] <= 4'hF ;
                else if (KEYS[1])
                    TIM_CTRS[g_idx] <= 4'hF ;
                else if (EN_CKS[g_idx])
                    TIM_CTRS[g_idx] <= TIM_CTRS[g_idx] + C_INCDATS[4*g_idx+:4] ;
            always @(posedge CK or negedge XARST)
                if ( ~ XARST)
                    LEDS[g_idx] <= 1'b0 ;
                else
                    if (g_idx==0)
                        LEDS[g_idx] <= (TIM_CTRS[g_idx] == TIM_CTRS[7]) ;                    else
                        LEDS[g_idx] <= (TIM_CTRS[g_idx] == TIM_CTRS[g_idx-1]) ;
        end
    endgenerate
    
    wire       BCD_cy ;
    reg [26:0]  BCD ;
    SUBREG_TIM_DIV #(
            .C_PERIOD_W( log2('d48_000_000) )
    )SUBREG_TIM_DIV(
          .CK_i     ( CK                    )
        , .XARST_i  ( XARST                 )
        , .RST_i    ( KEYS[1]               )
        , .PERIOD_i ( 48_000_000        )
        , .PULSE_N_i( 1                 )
        , .EN_CK_o  ( BCD_cy            )
    ) ;
    always @ (posedge CK or negedge XARST)
         if ( ~ XARST)
            BCD <= 4'h0 ;
        else if (KEYS[1])
             BCD <= 4'h0 ;
        else if (BCD_cy)
             BCD <= (BCD >= (10**8-1)) ? 0 : (BCD + 'd1111_1111) ;


    wire            MISO_i          ;
    wire            MOSI            ;
    wire            MOSI_OE         ;
    wire            SCLK_o          ;
    wire            SS_o            ;
//    wire    [ 7:0]  KEYS            ;
    wire            DB_FRAME_REQ_o  ;
    wire            DB_EN_SCLK_o    ;
    wire            DB_BUSY_o       ;
    wire            DB_BYTE_BUSY_o  ;
    wire            DB_KEY_STATE_o  ;
    reg             ENCBIN_XDIRECT ;
    wire            ENCBIN_XDIRECT_i  ;
    reg             BIN2BCD_ON        ;
    assign ENCBIN_XDIRECT_i = ENCBIN_XDIRECT ; //
    reg [7:0]   SUP_DIGITS ;
    TM1638_LED_KEY_DRV #(
          .C_FCK    ( C_FCK         )// Hz
        , .C_FSCLK  ( 1_000_000     )// Hz
        , .C_FPS    ( 250           )// cycle(Hz)
    ) TM1638_LED_KEY_DRV (
          .CK_i             ( CK            )
        , .XARST_i          ( XARST         )
        , .DIRECT7SEG0_i    ( 7'b0111111 )
        , .DIRECT7SEG1_i    ( 7'b0000110 )
        , .DIRECT7SEG2_i    ( 7'b1011011 )
        , .DIRECT7SEG3_i    ( 7'b1001111 )
        , .DIRECT7SEG4_i    ( 7'b1100110 )
        , .DIRECT7SEG5_i    ( 7'b1101101 )
        , .DIRECT7SEG6_i    ( 7'b1111101 )
        , .DIRECT7SEG7_i    ( 7'b0100111 )
        , .DOTS_i           ( KEYS      )
        , .LEDS_i           ( LEDS      )
        , .BIN_DAT_i        ( 
                        BIN2BCD_ON ?
                            BCD
                        :
                            {
                                  TIM_CTRS[7]
                                , TIM_CTRS[6]
                                , TIM_CTRS[5]
                                , TIM_CTRS[4]
                                , TIM_CTRS[3]
                                , TIM_CTRS[2]
                                , TIM_CTRS[1]
                                , TIM_CTRS[0]
                             })
        , .SUP_DIGITS_i     ( SUP_DIGITS    )
        , .ENCBIN_XDIRECT_i ( ENCBIN_XDIRECT_i)
        , .BIN2BCD_ON_i     ( BIN2BCD_ON  )
        , .MISO_i           ( MISO_i        )
        , .MOSI_o           ( MOSI          )
        , .MOSI_OE_o        ( MOSI_OE       )
        , .SCLK_o           ( SCLK_o        )
        , .SS_o             ( SS_o          )
        , .KEYS_o           ( KEYS          )
    ) ;
    reg [7:0] KEYS_D ;
    always @ (posedge CK )
        KEYS_D <= KEYS ;

    always @ (posedge CK or negedge XARST)
        if ( ~ XARST )
            ENCBIN_XDIRECT <= 1'b1 ;
        else if (KEYS[0] &  ~ KEYS_D[0])
            ENCBIN_XDIRECT <= ~ ENCBIN_XDIRECT ;
    always @ (posedge CK or negedge XARST)
        if ( ~ XARST)
            BIN2BCD_ON <= 1'b1 ;
        else if (KEYS[2] &  ~ KEYS_D[2])
            BIN2BCD_ON <= ~ BIN2BCD_ON ;


    generate
//        genvar g_idx ;
        for (g_idx=0 ; g_idx<8 ; g_idx=g_idx+1)begin :gen_SUPS
            always @ (posedge CK)
                    SUP_DIGITS[g_idx] <= KEYS[ g_idx ] ;
        end
    endgenerate 

    assign P124 = ( MOSI_OE ) ? MOSI : 1'bZ ; //DIO
//    assign P124 = MOSI ;
    assign MISO_i = P124 ;  //DIO
    assign P127 = SCLK_o ;  //CLK
    assign P130 = SS_o ;    //STB


//    assign P38 = TPAT_P_o ;
//    assign MISO_i = P39 ;
//    assign P41 = TPAT_N_o ;
//
//    assign P43 = CMP_P ;
//    assign P44 = CMP_N ;
//    
//    reg [3 :0] DAT_D        ;
//    reg [4 :0] TPAT_P_D     ;
//    reg [5 :0] CMP_P_ADJ    ;
//    always @(posedge CK48M_i) begin
//        DAT_D <={DAT_D[2:0] ,  DAT_i} ;
//        TPAT_P_D <= {TPAT_P_D[3:0], TPAT_P_o} ;
//        CMP_P_ADJ[0] <= ~ DAT_D[3] ^ TPAT_P_D[0] ;
//        CMP_P_ADJ[1] <= ~ DAT_D[2] ^ TPAT_P_D[0] ;
//        CMP_P_ADJ[2] <= ~ DAT_D[2] ^ TPAT_P_D[1] ; //return too late
//        CMP_P_ADJ[3] <= ~ DAT_D[2] ^ TPAT_P_D[2] ; //just
//        CMP_P_ADJ[4] <= ~ DAT_D[2] ^ TPAT_P_D[3] ; //return too fast
//        CMP_P_ADJ[5] <= ~ DAT_D[2] ^ TPAT_P_D[4] ;
//    end 
//    assign P43 = CMP_P_ADJ[0] ;
//    assign P44 = CMP_P_ADJ[1] ;
//    assign P45 = CMP_P_ADJ[2] ;
//    assign P46 = CMP_P_ADJ[3] ; <<
//    assign P47 = CMP_P_ADJ[4] ;
//    assign P48 = CMP_P_ADJ[5] ;

//    wire        QQ_o     ;
//    DELTA_SIGMA_1BIT_DAC #(
//        .C_DAT_W        ( 8 )
//    ) u_DELTA_SIGMA_DAC (
//          .CK           ( CK          )
//        , .XARST_i      ( XARST       )
//        , .DAT_i        ( VR_LOC      )
//        , .QQ_o         ( QQ_o        )
//        , .XQQ_o        ()
//    ) ; //u_DELTA_SIGNA_DAC
//
//    assign P17 = QQ_o ;


//    wire    [ 3 :0]     ACT_DIGIT_o ;
//    wire    [ 6 :0]     SEG7_o      ;
//    LED7SEG_DRV #(
//          .C_FCK   ( 48_000_000 )
//        , .C_FBLINK ( 1_0000     )
//    ) u_LED7SEG_DRV (
//          .CK_i         ( CK48M_i   )
//        , .XARST_i      ( XARST )
//        , .LATCH_i      ()
//        , .DAT_i        ( {8'h0 , VR_LOC} )
//        , .BUS_SUP0     ( 1'b1          )
//        , .ACT_DIGIT_o  ( ACT_DIGIT_o     )// act H out
//        , .SEG7_o       ( SEG7_o          )// segment out ;act H
//    ) ;
//    assign P62 = ~ SEG7_o[3] ;//d 3
//    assign P61 = ~ SEG7_o[0] ;//a 0
//    assign P60 = ~ SEG7_o[1] ;//b 1
//    assign P59 = ~ SEG7_o[5] ;//f 5
//    assign P58 = ~ SEG7_o[6] ;//g 6
//    assign P57 = ~ SEG7_o[2] ;//c 2
//    assign P56 = 
//    assign P55 = ~ SEG7_o[4] ;//e 4
//    assign P52 = ACT_DIGIT_o[3] ; //A3
//    assign P50 = ACT_DIGIT_o[2] ; //A2
//    assign P48 = //dot
//    assign P47 = 
//    assign P46 = ACT_DIGIT_o[1] ;//A1
//    assign P45 = ACT_DIGIT_o[0] ;//A0

    assign XLED_R_o = ~ 1'b0 ;
    assign XLED_G_o = ~ 1'b0 ;
    assign XLED_B_o = ~ 1'b0 ;

//    wire        SERVO_o         ;
//    wire        SERVO_FRAME_o   ;
//    SERVO_JR_DRV #(
//         .C_FCK ( 48_000_000    ) //[Hz]
//    ) u_SERVO_JR_DRV (
//          .CK_i     ( CK48M_i   )
//        , .XARST_i  ( XARST     )
//        , .DAT_i    ( VR_LOC    )
//        , .SERVO_o  ( SERVO_o   )
//        , .FRAME_o  ( SERVO_FRAME_o   )
//    ) ;
//    assign P14 = SERVO_o ;
//    assign P13 = SERVO_FRAME_o ;

//    wire    SOUND_o     ;
//    wire    XSOUND_o    ;
//    SOUNDER u_SONDER(
//          .CK_i     ( CK48M_i   )
//        , .XARST_i  ( XARST     )
//        , .KEY_i    ( VR_LOC    )
//        , .SOUND_o  ( SOUND_o   )
//        , .XSOUND_o ( XSOUND_o   )
//    ) ;
//    assign P124 = SOUND_o ;
//    assign P127 = XSOUND_o ;
    


endmodule //TM1638_LED_KEY_DRV_TOP
