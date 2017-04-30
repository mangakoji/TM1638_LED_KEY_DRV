// TM1638_LED_KEY_DRV.v
// TM1638_LED_KEY_DRV()
//
// TM1638 LED KEY BOARD using driver
// test in aitendo board vvv this
// http://www.aitendo.com/product/12887
// maybe move on many boards used TM1638
//
//
// twitter:@manga_koji
// hatena: id:mangakoji http://mangakoji.hatenablog.com/
// GitHub :@mangakoji
//2017-04-30sa  :1st

module TM1638_LED_KEY_DRV #(
      parameter C_FCK = 48_000_000  // Hz
    , parameter C_FSCLK = 1_000     // Hz
    , parameter C_FPS   =   250     // cycle(Hz)
)(
      input                 CK_i
    , input tri1            XARST_i
    , input tri0 [ 6 :0]    DIRECT7SEG0_i
    , input tri0 [ 6 :0]    DIRECT7SEG1_i
    , input tri0 [ 6 :0]    DIRECT7SEG2_i
    , input tri0 [ 6 :0]    DIRECT7SEG3_i
    , input tri0 [ 6 :0]    DIRECT7SEG4_i
    , input tri0 [ 6 :0]    DIRECT7SEG5_i
    , input tri0 [ 6 :0]    DIRECT7SEG6_i
    , input tri0 [ 6 :0]    DIRECT7SEG7_i
    , input tri0 [ 7 :0]    DOTS_i
    , input tri0 [ 7 :0]    LEDS_i
    , input tri0 [31 :0]    BIN_DAT_i
    , input tri0 [ 7 :0]    SUP_DIGITS_i
    , input tri0            ENCBIN_XDIRECT_i
    , input tri0            MISO_i
    , output                MOSI_o
    , output                MOSI_EN_o
    , output                SCLK_o
    , output                SS_o
    , output    [ 7:0]      KEYS_o
) ;
    function time log2;             //time is reg unsigned [63:0]
        input time value ;
    begin
        value = value-1;
        for (log2=0; value>0; log2=log2+1)
            value = value>>1;
    end endfunction


    //
    // ctl part
    //

    // clock divider
    //
    // if there is remainder ,round up
    localparam C_HALF_DIV_LEN = 
        C_FCK / (C_FSCLK * 2) 
        + 
        ((C_FCK % (C_FSCLK * 2)) ? 1 : 0) 
    ;
    localparam C_HALF_DIV_W = log2( C_HALF_DIV_LEN ) ;
    reg EN_HSCLK ;
    reg EN_SCLK ;
    reg EN_XSCLK ;
    reg EN_SCLK_D ;
    wire EN_CK ;
    reg [C_HALF_DIV_W-1 :0] H_DIV_CTR ;
    reg                     DIV_CTR ;
    wire    H_DIV_CTR_cy ;
    assign H_DIV_CTE_cy = &(H_DIV_CTR | ~(C_HALF_DIV_LEN-1)) ;
    always @(posedge CK_i or negedge XARST_i) 
        if (~ XARST_i) begin
            H_DIV_CTR <= 'd0 ;
            DIV_CTR  <= 1'd0 ;
            EN_HSCLK <= '1b0 ;
            EN_SCLK  <= '1b0 ;
            EN_XSCLK <= '1b0 ;
            EN_SCLK_D <= 1'b0 ;
        end else begin
            EN_HSCLK <= H_DIV_CTR_cy ;
            EN_SCLK  <= H_DIV_CTR_cy & ~ DIV_CTR ;
            EN_XSCLK <= H_DIV_CTR_cy &   DIV_CTR ;
            EN_SCLK_D <= EN_SCLK ;
            if (H_DIV_CTR_cy) begin
                H_DIV_CTR <= 'd0  ;
                DIV_CTR  <= ~ DIV_CTR ;
            end else begin
                H_DIV_CTR <= H_DIV_CTR + 'd1 ;
            end 
        end
    assign EN_CK = EN_XSCLK ;


    // gen cyclic FRAME_request
    //
    // fps define
    // SCLK CK count = C_HALF_DIV_LEN * 2
    // FCK / SCLK / FPS = SCLK clocks
    localparam C_FRAME_SCLK_N = C_FCK / (C_HALF_DIV_LEN * C_FPS) ;
    localparam C_F_CTR_W = log2( C_FRAME_SCLK_N ) ;
    reg [C_F_CTR_W-1:0] F_CTR ;
    reg                 FRAME_REQ ;
    wire                F_CTR_cy ;
    assign F_CTR_cy = &(F_CTR | ~( C_FRAME_SCLK_N-1)) ;
    always @(posedge CK_i or negedge XARST_i) 
        if (~ XARST_i) begin
            F_CTR <= 'd0 ;
            FRAME_REQ ;
        end else if (EN_CK) begin
            FRAME_REQ <= F_CTR_cy ;
            if (F_CTR_cy)
                F_CTR<= 'd0 ;
            else
                F_CTR <= F_CTR + 1 ;
        end


    // inter byte seqenser
    //
    wire BYTE_req ;//??
    localparam S_STARTUP    = 'hFF ;
    localparam S_IDLE       =   0 ;
    localparam S_LOAD       =   1 ;
    localparam S_BIT0       = 'h20 ;
    localparam S_BIT1       = 'h21 ;
    localparam S_BIT2       = 'h22 ;
    localparam S_BIT3       = 'h23 ;
    localparam S_BIT4       = 'h24 ;
    localparam S_BIT5       = 'h25 ;
    localparam S_BIT6       = 'h26 ;
    localparam S_BIT7       = 'h27 ;
    localparam S_FINISH     = 'h3F ;

    reg [7:0]   BYTE_STATE ;
    always @(posedge CK_i or negedge XARST_i) 
        if (~ XARST_i)
            BYTE_STATE <= S_STARTUP ;
        else if (EN_CK)
            case (BYTE_STATE)
                S_STARTUP    :
                    BYTE_STATE <= S_IDLE ;
                S_IDLE       :
                    if ( BYTE_req )
                        BYTE_STATE <= S_LOAD ;
                S_LOAD       :
                    BYTE_STATE <= S_BIT0 ;
                S_BIT0       :
                    BYTE_STATE <= S_BIT1 ;
                S_BIT1       :
                    BYTE_STATE <= S_BIT2 ;
                S_BIT2       :
                    BYTE_STATE <= S_BIT3 ;
                S_BIT3       : 
                    BYTE_STATE <= S_BIT4 ;
                S_BIT4       :
                    BYTE_STATE <= S_BIT5 ;
                S_BIT5       :
                    BYTE_STATE <= S_BIT6 ;
                S_BIT6       :
                    BYTE_STATE <= S_BIT7 ;
                S_BIT7       :
                    BYTE_STATE <= S_FINISH ; 
                S_FINISH       :
                    BYTE_STATE <= S_IDLE ; 
                default :
                    BYTE_STATE <= S_IDLE ;
            endcase


    // frame sequenser
    //
//    localparam S_STARTUP    = 'hFF ;
//    localparam S_IDLE       =   0 ;
//    localparam S_LOAD       =   1 ;
    localparam S_SEND_SET   =   2 ;
    localparam S_LED_ADR_SET=   4
    localparam S_LED0L     = 'h10 ;
    localparam S_LED0H     = 'h11 ;
    localparam S_LED1L     = 'h12 ;
    localparam S_LED1H     = 'h13 ;
    localparam S_LED2L     = 'h14 ;
    localparam S_LED2H     = 'h15 ;
    localparam S_LED3L     = 'h16 ;
    localparam S_LED2H     = 'h17 ;
    localparam S_LED2L     = 'h18 ;
    localparam S_LED4H     = 'h19 ;
    localparam S_LED4L     = 'h1A ;
    localparam S_LED5H     = 'h1B ;
    localparam S_LED5L     = 'h1C ;
    localparam S_LED6H     = 'h1D ;
    localparam S_LED7L     = 'h1E ;
    localparam S_LED7H     = 'h1F ;
    localparam S_LEDPWR_SET = 'h05 ;
    localparam S_KEY_ADR_SET = 'h06 ;
    localparam S_KEY0      = 'h20 ;
    localparam S_KEY1      = 'h21 ;
    localparam S_KEY2      = 'h22 ;
    localparam S_KEY3      = 'h23 ;
    reg         MISO_OE ;
    reg [ 7 :0] FRAME_STATE ;
    always @(posedge CK_i or negedge XARST_i) 
        if (~ XARST_i)
            FRAME_STATE <= S_STARTUP ;
        else if (EN_CK)
            case (FRAME_STATE)
                S_STARTUP    :
                    FRAME_STATE <= S_IDLE
                S_IDLE       :
                    if ( FRAME_REQ )
                        FRAME_STATE <= S_LOAD ;
                S_LOAD       : //7seg convert
                    if (BYTE_STATE==S_FINISH)
                        FRAME_STATE <= S_SEND_SET ;
                S_SEND_SET   :
                    if (BYTE_STATE==S_FINISH)
                        FRAME_STATE <= S_LED_ADR_SET ;
                S_LED_ADR_SET:
                    if (BYTE_STATE==S_FINISH)
                        FRAME_STATE <= S_LED0L ;
                S_LED0L     :
                    if (BYTE_STATE==S_FINISH)
                        FRAME_STATE <= S_LED0H ;
                S_LED0H     :
                    if (BYTE_STATE==S_FINISH)
                        FRAME_STATE <= S_LED1L ;
                S_LED1L     :
                    if (BYTE_STATE==S_FINISH)
                        FRAME_STATE <= S_LED1H ;
                S_LED1H     :
                    if (BYTE_STATE==S_FINISH)
                        FRAME_STATE <= S_LED2L ;
                S_LED2L     :
                    if (BYTE_STATE==S_FINISH)
                        FRAME_STATE <= S_LED2H ;
                S_LED2H     :
                    if (BYTE_STATE==S_FINISH)
                        FRAME_STATE <= S_LED3L ;
                S_LED3L     :
                    if (BYTE_STATE==S_FINISH)
                        FRAME_STATE <= S_LED3H ;
                S_LED3H     :
                    if (BYTE_STATE==S_FINISH)
                        FRAME_STATE <= S_LED4L ;
                S_LED4L     :
                    if (BYTE_STATE==S_FINISH)
                        FRAME_STATE <= S_LED4H ;
                S_LED4H     :
                    if (BYTE_STATE==S_FINISH)
                        FRAME_STATE <= S_LED5L ;
                S_LED5L     :
                    if (BYTE_STATE==S_FINISH)
                        FRAME_STATE <= S_LED5H ;
                S_LED5H     :
                    if (BYTE_STATE==S_FINISH)
                        FRAME_STATE <= S_LED6L ;
                S_LED6L     :
                    if (BYTE_STATE==S_FINISH)
                        FRAME_STATE <= S_LED6H ;
                S_LED6H     :
                    if (BYTE_STATE==S_FINISH)
                        FRAME_STATE <= S_LED7L ;
                S_LED7L     :
                    if (BYTE_STATE==S_FINISH)
                        FRAME_STATE <= S_LED7H ;
                S_LED7H     :
                    if (BYTE_STATE==S_FINISH)
                        FRAME_STATE <= S_LEDPWR_SET ;
                S_LEDPWR_SET :
                    if (BYTE_STATE==S_FINISH)
                        FRAME_STATE <= S_KEY_ADR_SET ;
                S_KEY_ADR_SET :
                    if (BYTE_STATE==S_FINISH)
                        FRAME_STATE <= S_KEY0 ;
                S_KEY0      : 
                    if (BYTE_STATE==S_FINISH)
                        FRAME_STATE <= S_KEY1 ;
                S_KEY1      :
                    if (BYTE_STATE==S_FINISH)
                        FRAME_STATE <= S_KEY2 ;
                S_KEY2      :
                    if (BYTE_STATE==S_FINISH)
                        FRAME_STATE <= S_KEY3 ;
                S_KEY3     :
                    if (BYTE_STATE==S_FINISH)
                        FRAME_STATE <= S_FINISH ;
                S_FINISH     :
                    if (BYTE_STATE==S_FINISH)
                        FRAME_STATE <= S_IDLE ;
            endcase

    reg MOSI_OE  ;
    always @(posedge CK_i or negedge XARST_i)
        if (~ XARST_i)
            MISO_OE <= 1'b0 ;
        else if( EN_CK) // EN_XSCLK
            if (BYTE_STATE == S_BIT7)
                MISO_OE <= 1'b0 ;
            else if (BYTE_STATE == S_LOAD)
                case (FRAME_STATE)
                    S_SEND_SET :
                    S_LED_ADR_SET :
                    S_LED0L :
                    S_LED0H :
                    S_LED1L :
                    S_LED1H :
                    S_LED2L :
                    S_LED2H :
                    S_LED3L :
                    S_LED3H :
                    S_LED4L :
                    S_LED4H :
                    S_LED5L :
                    S_LED5H :
                    S_LED6L :
                    S_LED6H :
                    S_LED7L :
                    S_LED7H :
                    S_LEDPWR_SET :
                    S_KEY_ADR_SET :
                        MISO_OE <= 1'b1 ;
                endcase
    assign MOSI_OE_o = MOSI_OE ;


    reg SCLK ;
    always @(posedge CK_i or negedge XARST_i)
        if (~ XARST_i)
            SCLK <= 1'b1 ;
        else if( EN_SCLK )
            SCLK <= 1'b1 ;
        else if (EN_XSCLK)
            case (BYTE_STATE)
                S_LOAD :
                S_BIT0 :
                S_BIT1 :
                S_BIT2 :
                S_BIT3 :
                S_BIT4 :
                S_BIT5 :
                S_BIT6 :
                S_BIT7 :
                    SCLK <= 1'b0 ;
            endcase

    assign SCLK_o = SCLK ;

    reg SS ;
    always @(posedge CK_i or negedge XARST_i)
        if (~ XARST_i)
            SS <= 1'b1 ;
        else if( EN_CK)
            if (BYTE_STATE == S_LOAD)
                case ( FRAME_STATE )
                    S_SEND_SET :
                    S_LED_ADR_SET :
                    S_LEDPWR_SET :
                    S_KEY_ADR_SET :
                        SS <= 1'b1 ;
        else if (EN_SCLK)
            if (BYTE_STATE == S_FINISH)
                case ( FRAME_STATE )
                    S_SEND_ADR_SET :
                    S_LED7H :
                    S_LEDPWR_SET :
                    S_KEY3 :
                        SS <= 1'b0 ;

    
    // main data part
    //
    //

    reg             ENC_SHIFT ;
    always @(posedge CK_i or negedge XARST_i)
        if (~ XARST_i)
            ENC_SHIFT <= 1'b0 ;
        else if ( EN_CK )
            if (FRAME_REQ )
                ENC_SHIFT <= 1'b1 ;
            else
                case (BYTE_STATE)
                    S_BIT5 :
                        ENC_SHIFT <= 1'b0 ;
                endcase
            end
    wire    [34:0]  DAT_BUF ;   //5bit downsized, but too complex
    always @(posedge CK_i or negedge XARST_i)
        if (~ XARST_i)
            DAT_BUF <= 35'd0 ;
        else if (EN_CK)
            if (FRAME_REQ )
                DAT_BUF <= {
                      SUP_DIGITS_i[6]
                    , BIN_DAT     [6*4 +:4]
                    , SUP_DIGITS_i[5]
                    , BIN_DAT     [5*4 +:4]
                    , SUP_DIGITS_i[4]
                    , BIN_DAT     [4*4 +:4]
                    , SUP_DIGITS_i[3]
                    , BIN_DAT     [3*4 +:4]
                    , SUP_DIGITS_i[2]
                    , BIN_DAT     [2*4 +:4]
                    , SUP_DIGITS_i[1]
                    , BIN_DAT     [1*4 +:4]
                    , SUP_DIGITS_i[0]
                    , BIN_DAT     [0*4 +:4]
                } ;
            else
                DAT_BUF <= {
                      DAT_BUF[29:0]
                    , 5'b0
                } ;
    wire [ 3 :0] octet_seled ;
    wire        sup_now ;
    assign {sup_now, octet_seled } = 
        ( FRAME_REQ ) ? 
                {SUP_DIGITS_i[7], BIN_DAT[31:28]} 
            : 
                DAT_BUF[34 -:5] 
    ;


    // endcoder for  LED7-segment
    //   a 
    // f     b
    //    g
    // e     c
    //    d 

    always @(posedge CK_i or negedge XARST_i)
        if (~ XARST_i)

    wire    [ 6 :0] enced_7seg ;
    function [6:0] f_seg_enc ;
        input sup_now ;
        input [3:0] octet;
    begin
        if (sup_now)
            f_seg_enc = 7'b1000000 ;
        else
          case( octet )
                              //  gfedcba
            4'h0 : f_seg_enc = 7'b0111111 ; //0
            4'h1 : f_seg_enc = 7'b0000110 ; //1
            4'h2 : f_seg_enc = 7'b1011011 ; //2
            4'h3 : f_seg_enc = 7'b1001111 ; //3
            4'h4 : f_seg_enc = 7'b1100110 ; //4
            4'h5 : f_seg_enc = 7'b1101101 ; //5
            4'h6 : f_seg_enc = 7'b1111101 ; //6
            4'h7 : f_seg_enc = 7'b0100111 ; //7
            4'h8 : f_seg_enc = 7'b1111111 ; //8
            4'h9 : f_seg_enc = 7'b1101111 ; //9
            4'hA : f_seg_enc = 7'b1110111 ; //a
            4'hB : f_seg_enc = 7'b1111100 ; //b
            4'hC : f_seg_enc = 7'b0111001 ; //c
            4'hD : f_seg_enc = 7'b1011110 ; //d
            4'hE : f_seg_enc = 7'b1111001 ; //e
            4'hF : f_seg_enc = 7'b1110001 ; //f
            default : f_seg_enc = 7'b1000000 ; //-
          endcase
    end endfunction
    assign enced_7seg = f_seg_enc(sup_now , octet_seled ) ;


//    wire    ENCBIN_XDIRECT_y ;
    reg     ENCBIN_XDIRECT_D ;
   always @(posedge CK_i or negedge XARST_i)
        if (~ XARST_i)
            ENCBIN_XDIRECT_D <= 1'b0 ;
        else if( FRAME_REQ )
            ENCBIN_XDIRECT_D <= ENCBIN_XDIRECT_i ;
//    assign ENCBIN_XDIRECT_y = (FRAME_REQ)? ENCBIN_XDIRECT_i : ENCBIN_XDIRECT


    reg     [71 :0] MAIN_BUFF ; //7bit downsize but too complex.
    always @(posedge CK_i or negedge XARST_i)
        if (~ XARST_i)
            MAIN_BUFF <= 72'd0 ;
        else if (ENC_CK)
            else if ( FRAME_REQ ) begin
                 MAIN_BUFF[71:7] <= {
                     , LEDS_i[0]
                     , DOTS_i[0]
                     , DIRECT7SG0_i
                     , LEDS_i[1]
                     , DOTS_i[1]
                     , DIRECT7SG1_i
                     , LEDS_i[2]
                     , DOTS_i[2]
                     , DIRECT7SG2_i
                     , LEDS_i[3]
                     , DOTS_i[3]
                     , DIRECT7SG3_i
                     , LEDS_i[4]
                     , DOTS_i[4]
                     , DIRECT7SG4_i
                     , LEDS_i[5]
                     , DOTS_i[5]
                     , DIRECT7SG5_i
                     , LEDS_i[6]
                     , DOTS_i[6]
                     , DIRECT7SG6_i
                     , LEDS_i[7]
                     , DOTS_i[7]
                 }
                 if (ENCBIN_XDIRECT)
                     MAIN_BUF[6:0] <= enced_7seg ;
                 else
                     MAIN_BUF[6:0] <= DIRECT7SEG7_i ;
             end else if (FRAME_REQ_D & ENC_SHIFT)
                 case (FRAME_STATE)
                     S_LOAD :
                         MAIN_BUF <=  {
                               MAIN_BUF[ 8: 0]
                             , MAIN_BUF[71:18]
                             , MAIN_BUF[17:16]
                             , enced_7seg 
                         } ;
                 endcase
             else 
                 case (FRAME_STATE)
                     S_LED0L :
                     S_LED1L :
                     S_LED2L :
                     S_LED3L :
                     S_LED4L :
                     S_LED5L :
                     S_LED6L :
                     S_LED7L :
                         case ( BYTE_STATE )
                             S_BIT0 :
                             S_BIT1 :
                             S_BIT2 :
                             S_BIT3 :
                             S_BIT4 :
                             S_BIT5 :
                             S_BIT6 :
                             S_BIT7 :
                                 MAIN_BUF <= {
                                      MAIN_BUF[0]
                                     , MAIN_BUF[71:1]
                                 } ;
                         endcase
                     S_LED0H :
                     S_LED1H :
                     S_LED2H :
                     S_LED3H :
                     S_LED4H :
                     S_LED5H :
                     S_LED6H :
                     S_LED7H :
                         case ( BYE_STATE )
                             S_BIT0 :
                             S_BIT1 :
                                 MAIN_BUF <= {
                                       MAIN_BUF[0]
                                     , MAIN_BUF[71:1]
                                 }
                         endcase


    reg [ 7 :0] KEYS ;
    always @(posedge CK_i or negedge XARST_i) 
        if ( ~ XARST_i )
            KEYS <= 8'd0 ;
        else if ( EN_SCLK_D )
            case (FRAME_STATE)
                S_KEY0 : 
                    if ( BYTE_STATE == S_BIT0)
                        KEYS[7] <= MISO_i ;
                    else if(BYTE_STATE == S_BIT4)
                        KEYS[6] <= MISO_i ;
                S_KEY1 : 
                    if ( BYTE_STATE == S_BIT0)
                        KEYS[5] <= MISO_i ;
                    else if(BYTE_STATE == S_BIT4)
                        KEYS[4] <= MISO_i ;
                S_KEY2 : 
                    if ( BYTE_STATE == S_BIT0)
                        KEYS[3] <= MISO_i ;
                    else if(BYTE_STATE == S_BIT4)
                        KEYS[2] <= MISO_i ;
                S_KEY3 : 
                    if ( BYTE_STATE == S_BIT0)
                        KEYS[1] <= MISO_i ;
                    else if(BYTE_STATE == S_BIT4)
                        KEYS[0] <= MISO_i ;
            endcase
    assign KEYS_o = KEYS ;

endmodule

