//VR_LOC_DET_TOP.v
//      VR_LOC_DET top
//      pulse counter 
//
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

module VR_LOC_DET_TOP(
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
    wire            CK              ;
    wire            XAR             ;
    wire            XARST           ;
    wire            CK196M          ;
    assign CK = CK48M_i ;
    PLL u_PLL(
              .areset       ( 1'b0          )
            , .inclk0       ( CK48M_i       )
            , .c0           ( CK196M        )
            , .locked       ( XARST         )
    ) ;

    wire            TPAT_P_o    ;
    wire            DAT_i       ;
    wire            TPAT_N_o    ;
    wire    [ 7 :0] VR_LOC      ;
    wire            CMP_P       ;
    wire            CMP_N       ;
    VR_LOC_DET VR_LOC_DET (
          .CK_i     ( CK48M_i       )
        , .XARST_i  ( XARST         )
        , .EN_CK_i  ( 1'b1          )
        , .DAT_i    ( DAT_i         )
        , .TPAT_P_o ( TPAT_P_o      )
        , .TPAT_N_o ( TPAT_N_o      )
        , .CMP_P_o  ( CMP_P         )
        , .CMP_N_o  ( CMP_N         )
        , .LOC_o    ( VR_LOC        )
    ) ;
    assign P38 = TPAT_P_o ;
    assign DAT_i = P39 ;
    assign P41 = TPAT_N_o ;

    assign P43 = CMP_P ;
    assign P44 = CMP_N ;
    
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

    wire        QQ_o     ;
    DELTA_SIGMA_1BIT_DAC #(
        .C_DAT_W        ( 8 )
    ) u_DELTA_SIGMA_DAC (
          .CK           ( CK          )
        , .XARST_i      ( XARST       )
        , .DAT_i        ( VR_LOC      )
        , .QQ_o         ( QQ_o        )
        , .XQQ_o        ()
    ) ; //u_DELTA_SIGNA_DAC

    assign P17 = QQ_o ;


    wire    [ 3 :0]     ACT_DIGIT_o ;
    wire    [ 6 :0]     SEG7_o      ;
    LED7SEG_DRV #(
          .C_FCK   ( 48_000_000 )
        , .C_FBLINK ( 1_0000     )
    ) u_LED7SEG_DRV (
          .CK_i         ( CK48M_i   )
        , .XARST_i      ( XARST )
        , .LATCH_i      ()
        , .DAT_i        ( {8'h0 , VR_LOC} )
        , .BUS_SUP0     ( 1'b1          )
        , .ACT_DIGIT_o  ( ACT_DIGIT_o     )// act H out
        , .SEG7_o       ( SEG7_o          )// segment out ;act H
    ) ;
    assign P62 = ~ SEG7_o[3] ;//d 3
    assign P61 = ~ SEG7_o[0] ;//a 0
    assign P60 = ~ SEG7_o[1] ;//b 1
    assign P59 = ~ SEG7_o[5] ;//f 5
    assign P58 = ~ SEG7_o[6] ;//g 6
    assign P57 = ~ SEG7_o[2] ;//c 2
//    assign P56 = 
    assign P55 = ~ SEG7_o[4] ;//e 4

    assign P52 = ACT_DIGIT_o[3] ; //A3
    assign P50 = ACT_DIGIT_o[2] ; //A2
//    assign P48 = //dot
//    assign P47 = 
    assign P46 = ACT_DIGIT_o[1] ;//A1
    assign P45 = ACT_DIGIT_o[0] ;//A0

    assign XLED_R_o = ~ VR_LOC[7] ;
    assign XLED_G_o = ~ 1'b0 ;
    assign XLED_B_o = ~ 1'b0 ;

    wire        SERVO_o         ;
    wire        SERVO_FRAME_o   ;
    SERVO_JR_DRV #(
         .C_FCK ( 48_000_000    ) //[Hz]
    ) u_SERVO_JR_DRV (
          .CK_i     ( CK48M_i   )
        , .XARST_i  ( XARST     )
        , .DAT_i    ( VR_LOC    )
        , .SERVO_o  ( SERVO_o   )
        , .FRAME_o  ( SERVO_FRAME_o   )
    ) ;
    assign P14 = SERVO_o ;
    assign P13 = SERVO_FRAME_o ;

    wire    SOUND_o     ;
    wire    XSOUND_o    ;
    SOUNDER u_SONDER(
          .CK_i     ( CK48M_i   )
        , .XARST_i  ( XARST     )
        , .KEY_i    ( VR_LOC    )
        , .SOUND_o  ( SOUND_o   )
        , .XSOUND_o ( XSOUND_o   )
    ) ;
    assign P124 = SOUND_o ;
    assign P127 = XSOUND_o ;
    


endmodule //VR_LOC_DET_TOP
