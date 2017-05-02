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
//
//
//2017-05-02tu  013 :all feature passed
//              011 :almost passed, remind SUP_DIGITS
//              010 :DIRECT passed, ENC7SEG debug prepare commit
//2017-05-01mo  008 :1st compile is passed , debug start
//              007 :1ce wrote
//2017-04-29sa  :1st

module TM1638_LED_KEY_DRV #(
      parameter C_FCK  =  48_000_000  // Hz
    , parameter C_FSCLK =  1_000_000  // Hz
    , parameter C_FPS   =        250  // cycle(Hz)
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
    , output                MOSI_OE_o
    , output                SCLK_o
    , output                SS_o
    , output    [ 7:0]      KEYS_o
    , output                DB_FRAME_REQ_o 
    , output                DB_EN_SCLK_o
    , output                DB_BUSY_o
    , output                DB_BYTE_BUSY_o
    , output                DB_KEY_STATE_o
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
    localparam C_HALF_DIV_LEN = //24
        C_FCK / (C_FSCLK * 2) 
        + 
        ((C_FCK % (C_FSCLK * 2)) ? 1 : 0) 
    ;
    localparam C_HALF_DIV_W = log2( C_HALF_DIV_LEN ) ;
//    reg EN_HSCLK ;
    reg EN_SCLK ;
    reg EN_XSCLK ;
    reg EN_SCLK_D ;
    wire EN_CK ;
    reg [C_HALF_DIV_W-1 :0] H_DIV_CTR ;
    reg                     DIV_CTR ;
    wire    H_DIV_CTR_cy ;
    assign H_DIV_CTR_cy = &(H_DIV_CTR | ~(C_HALF_DIV_LEN-1)) ;
    always @(posedge CK_i or negedge XARST_i) 
        if (~ XARST_i) begin
            H_DIV_CTR <= 'd0 ;
            DIV_CTR  <=  1'd0 ;
//            EN_HSCLK <=  1'b0 ;
            EN_SCLK  <=  1'b0 ;
            EN_XSCLK <=  1'b0 ;
            EN_SCLK_D <= 1'b0 ;
        end else begin
//            EN_HSCLK <= H_DIV_CTR_cy ;
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
    assign DB_EN_SCLK_o = EN_SCLK ;

    // gen cyclic FRAME_request
    //
    // fps define
    // SCLK CK count = C_HALF_DIV_LEN * 2
    // FCK / SCLK / FPS = SCLK clocks
    localparam C_FRAME_SCLK_N = C_FCK / (C_HALF_DIV_LEN * C_FPS) ; //8000
    localparam C_F_CTR_W = log2( C_FRAME_SCLK_N ) ;
    reg [C_F_CTR_W-1:0] F_CTR ;
    reg                 FRAME_REQ ;
    reg                 FRAME_REQ_D ;
    wire                F_CTR_cy ;
    assign F_CTR_cy = &(F_CTR | ~( C_FRAME_SCLK_N-1)) ;
    always @(posedge CK_i or negedge XARST_i) 
        if (~ XARST_i) begin
            F_CTR <= 'd0 ;
            FRAME_REQ <= 1'b0 ;
            FRAME_REQ_D <= 1'b0 ;
        end else if (EN_CK) begin
            FRAME_REQ <= F_CTR_cy ;
            FRAME_REQ_D <= FRAME_REQ ;
            if (F_CTR_cy)
                F_CTR<= 'd0 ;
            else
                F_CTR <= F_CTR + 1 ;
        end


    // inter byte seqenser
    //
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

    localparam S_KEY3      = 'h23 ;
    reg [ 7 :0] FRAME_STATE ;

    reg [7:0]   BYTE_STATE ;
    always @(posedge CK_i or negedge XARST_i) 
        if (~ XARST_i)
            BYTE_STATE <= S_STARTUP ;
        else if (EN_CK)
            if ( FRAME_REQ )
                BYTE_STATE <= S_LOAD ;
            else case (BYTE_STATE)
                S_STARTUP    :
                    BYTE_STATE <= S_IDLE ;
                S_IDLE       : 
                    case ( FRAME_STATE )
                          S_IDLE :
                            ; //pass 
                        default :
                            BYTE_STATE <= S_LOAD ;
                    endcase
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
    localparam S_LED_ADR_SET=   4 ;
    localparam S_LED0L     = 'h10 ;
    localparam S_LED0H     = 'h11 ;
    localparam S_LED1L     = 'h12 ;
    localparam S_LED1H     = 'h13 ;
    localparam S_LED2L     = 'h14 ;
    localparam S_LED2H     = 'h15 ;
    localparam S_LED3L     = 'h16 ;
    localparam S_LED3H     = 'h17 ;
    localparam S_LED4L     = 'h18 ;
    localparam S_LED4H     = 'h19 ;
    localparam S_LED5L     = 'h1A ;
    localparam S_LED5H     = 'h1B ;
    localparam S_LED6L     = 'h1C ;
    localparam S_LED6H     = 'h1D ;
    localparam S_LED7L     = 'h1E ;
    localparam S_LED7H     = 'h1F ;
    localparam S_LEDPWR_SET = 'h05 ;
    localparam S_KEY_ADR_SET = 'h06 ;
    localparam S_KEY0      = 'h20 ;
    localparam S_KEY1      = 'h21 ;
    localparam S_KEY2      = 'h22 ;
//    localparam S_KEY3      = 'h23 ;
//    reg [ 7 :0] FRAME_STATE ;
    always @(posedge CK_i or negedge XARST_i) 
        if (~ XARST_i)
            FRAME_STATE <= S_STARTUP ;
        else if (EN_CK)
            if (FRAME_REQ)
                FRAME_STATE <= S_LOAD ;
            else case (FRAME_STATE)
                S_STARTUP    :
                    FRAME_STATE <= S_IDLE ;
                S_IDLE       :
                    if ( FRAME_REQ )
                        FRAME_STATE <= S_LOAD ;
                S_LOAD       : //7seg convert
                    case ( BYTE_STATE )
                        S_FINISH :
                            FRAME_STATE <= S_SEND_SET ;
                    endcase
                S_SEND_SET   :
                    case ( BYTE_STATE )
                        S_FINISH :
                            FRAME_STATE <= S_LED_ADR_SET ;
                    endcase
                S_LED_ADR_SET:
                    case ( BYTE_STATE )
                        S_FINISH :
                            FRAME_STATE <= S_LED0L ;
                    endcase
                S_LED0L     :
                    case ( BYTE_STATE )
                        S_FINISH :
                            FRAME_STATE <= S_LED0H ;
                    endcase
                S_LED0H     :
                    case ( BYTE_STATE )
                        S_FINISH :
                            FRAME_STATE <= S_LED1L ;
                    endcase
                S_LED1L     :
                    case ( BYTE_STATE )
                        S_FINISH :
                            FRAME_STATE <= S_LED1H ;
                    endcase
                S_LED1H     :
                    case ( BYTE_STATE )
                        S_FINISH :
                            FRAME_STATE <= S_LED2L ;
                    endcase
                S_LED2L     :
                    case ( BYTE_STATE )
                        S_FINISH :
                            FRAME_STATE <= S_LED2H ;
                    endcase
                S_LED2H     :
                    case ( BYTE_STATE )
                        S_FINISH :
                            FRAME_STATE <= S_LED3L ;
                    endcase
                S_LED3L     :
                    case ( BYTE_STATE )
                        S_FINISH :
                            FRAME_STATE <= S_LED3H ;
                    endcase
                S_LED3H     :
                    case ( BYTE_STATE )
                        S_FINISH :
                            FRAME_STATE <= S_LED4L ;
                    endcase
                S_LED4L     :
                    case ( BYTE_STATE )
                        S_FINISH :
                            FRAME_STATE <= S_LED4H ;
                    endcase
                S_LED4H     :
                    case ( BYTE_STATE )
                        S_FINISH :
                            FRAME_STATE <= S_LED5L ;
                    endcase
                S_LED5L     :
                    case ( BYTE_STATE )
                        S_FINISH :
                            FRAME_STATE <= S_LED5H ;
                    endcase
                S_LED5H     :
                    case ( BYTE_STATE )
                        S_FINISH :
                            FRAME_STATE <= S_LED6L ;
                    endcase
                S_LED6L     :
                    case ( BYTE_STATE )
                        S_FINISH :
                            FRAME_STATE <= S_LED6H ;
                    endcase
                S_LED6H     :
                    case ( BYTE_STATE )
                        S_FINISH :
                            FRAME_STATE <= S_LED7L ;
                    endcase
                S_LED7L     :
                    case ( BYTE_STATE )
                        S_FINISH :
                            FRAME_STATE <= S_LED7H ;
                    endcase
                S_LED7H     :
                    case ( BYTE_STATE )
                        S_FINISH :
                            FRAME_STATE <= S_LEDPWR_SET ;
                    endcase
                S_LEDPWR_SET :
                    case ( BYTE_STATE )
                        S_FINISH :
                            FRAME_STATE <= S_KEY_ADR_SET ;
                    endcase
                S_KEY_ADR_SET :
                    case ( BYTE_STATE )
                        S_FINISH :
                            FRAME_STATE <= S_KEY0 ;
                    endcase
                S_KEY0      : 
                    case ( BYTE_STATE )
                        S_FINISH :
                            FRAME_STATE <= S_KEY1 ;
                    endcase
                S_KEY1      :
                    case ( BYTE_STATE )
                        S_FINISH :
                            FRAME_STATE <= S_KEY2 ;
                    endcase
                S_KEY2      :
                    case ( BYTE_STATE )
                        S_FINISH :
                            FRAME_STATE <= S_KEY3 ;
                    endcase
                S_KEY3     :
                    case ( BYTE_STATE )
                        S_FINISH :
                            FRAME_STATE <= S_IDLE ;
                    endcase
                S_FINISH     :
                    case ( BYTE_STATE )
                        S_FINISH :
                            FRAME_STATE <= S_IDLE ;
                    endcase
            endcase


    reg BUSY ;
    always @(posedge CK_i or negedge XARST_i)
        if (~ XARST_i)
            BUSY <= 1'b0 ;
        else
            case (FRAME_STATE)
                S_IDLE :
                    ;//pas
                default :
                    case (BYTE_STATE )
                        S_IDLE :
                            BUSY <= 1'b0 ;
                        default :
                            BUSY <= 1'b1 ;
                    endcase
            endcase
    assign DB_BUSY_o = BUSY ;
    reg BYTE_BUSY ;
    always @(posedge CK_i or negedge XARST_i)
        if (~ XARST_i)
            BYTE_BUSY <= 1'b0 ;
        else
            case ( BYTE_STATE )
                S_IDLE :
                    BYTE_BUSY <= 1'b0 ;
                default :
                    BYTE_BUSY <= 1'b1 ;
            endcase
    assign DB_BYTE_BUSY_o = BYTE_BUSY ;
    reg KEY_STATE ;
    always @(posedge CK_i or negedge XARST_i)
        if (~ XARST_i)
            KEY_STATE <= 1'b0 ;
        else
            case ( FRAME_STATE )
                  S_KEY0
                , S_KEY1
                , S_KEY2
                , S_KEY3 :
                    KEY_STATE <= 1'b1 ;
                default :
                    KEY_STATE <= 1'b0 ;
            endcase
    assign DB_KEY_STATE_o = KEY_STATE ;
    

    reg MOSI_OE  ;
    always @(posedge CK_i or negedge XARST_i)
        if (~ XARST_i)
            MOSI_OE <= 1'b0 ;
        else if( EN_CK) begin // EN_XSCLK
            case ( BYTE_STATE )
                S_BIT7 :
                    MOSI_OE <= 1'b0 ;
                S_LOAD : 
                    case ( FRAME_STATE )
                          S_SEND_SET
                        , S_LED_ADR_SET
                        , S_LED0L
                        , S_LED0H
                        , S_LED1L
                        , S_LED1H
                        , S_LED2L
                        , S_LED2H
                        , S_LED3L
                        , S_LED3H
                        , S_LED4L
                        , S_LED4H
                        , S_LED5L
                        , S_LED5H
                        , S_LED6L
                        , S_LED6H
                        , S_LED7L
                        , S_LED7H
                        , S_LEDPWR_SET
                        , S_KEY_ADR_SET :
                            MOSI_OE <= 1'b1 ;
                    endcase
            endcase
        end

    reg SCLK ;
    always @(posedge CK_i or negedge XARST_i)
        if (~ XARST_i)
            SCLK <= 1'b1 ;
        else if( EN_SCLK )
            SCLK <= 1'b1 ;
        else if (EN_XSCLK)
            case ( FRAME_STATE)
                  S_IDLE 
                , S_LOAD
                , S_FINISH :
                    SCLK <= 1'b1 ;
                default :
                    case (BYTE_STATE)
                          S_LOAD
                        , S_BIT0
                        , S_BIT1
                        , S_BIT2
                        , S_BIT3
                        , S_BIT4
                        , S_BIT5
                        , S_BIT6 :
                            SCLK <= 1'b0 ;
                    endcase
            endcase


    reg SS ;
    always @(posedge CK_i or negedge XARST_i)
        if (~ XARST_i)
            SS <= 1'b1 ;
        else begin
            if( EN_SCLK )
                case (BYTE_STATE)
                    S_LOAD :
                        case ( FRAME_STATE )
                              S_SEND_SET
                            , S_LED_ADR_SET
                            , S_LEDPWR_SET
                            , S_KEY_ADR_SET :
                                SS <= 1'b0 ;
                        endcase
                    endcase
            else if ( EN_XSCLK ) begin
                if ( FRAME_REQ )
                    SS <= 1'b1 ;
                case (BYTE_STATE)
                    S_FINISH :
                        case ( FRAME_STATE )
                              S_SEND_SET
                            , S_LED7H
                            , S_LEDPWR_SET
                            , S_KEY3 :
                                SS <= 1'b1 ;
                        endcase
                endcase
            end
        end
    assign SCLK_o    = SCLK  ;
    assign MOSI_OE_o = MOSI_OE ;
    assign SS_o      = SS ;



    // main data part
    //
    //
    reg     [34:0]  DAT_BUFF ;   //5bit downsized, but too complex
    always @(posedge CK_i or negedge XARST_i)
        if (~ XARST_i)
            DAT_BUFF <= 35'd0 ;
        else if (EN_CK)
            if (FRAME_REQ )
                DAT_BUFF <= {
                      SUP_DIGITS_i  [7]
                    , BIN_DAT_i     [7*4 +:4]
                    , SUP_DIGITS_i  [6]
                    , BIN_DAT_i     [6*4 +:4]
                    , SUP_DIGITS_i  [5]
                    , BIN_DAT_i     [5*4 +:4]
                    , SUP_DIGITS_i  [4]
                    , BIN_DAT_i     [4*4 +:4]
                    , SUP_DIGITS_i  [3]
                    , BIN_DAT_i     [3*4 +:4]
                    , SUP_DIGITS_i  [2]
                    , BIN_DAT_i     [2*4 +:4]
                    , SUP_DIGITS_i  [1]
                    , BIN_DAT_i     [1*4 +:4]
                } ;
            else
                DAT_BUFF <= {
                      5'b0
                    , DAT_BUFF[34:5]
                } ;


    wire [ 3 :0] octet_seled ;
    wire        sup_now ;
    assign {sup_now, octet_seled } = 
        ( FRAME_REQ ) ? 
                {SUP_DIGITS_i[0], BIN_DAT_i[3:0]} 
            : 
                DAT_BUFF[ 4 :0] 
    ;

    // endcoder for  LED7-segment
    //   a 
    // f     b
    //    g
    // e     c
    //    d 
    wire    [ 6 :0] enced_7seg ;
    function [6:0] f_seg_enc ;
        input sup_now ;
        input [3:0] octet;
    begin
        if (sup_now)
            f_seg_enc = 7'b000_0000 ;
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


    reg     [71 :0] MAIN_BUFF ; //7bit downsize but too complex.
    always @(posedge CK_i or negedge XARST_i)
        if (~ XARST_i)
            MAIN_BUFF <= 72'd0 ;
        else if ( EN_CK )
            if ( FRAME_REQ ) begin
                 MAIN_BUFF[71:7] <= {
                       LEDS_i[0]
                     , DOTS_i[0]
                     , DIRECT7SEG0_i
                     , LEDS_i[1]
                     , DOTS_i[1]
                     , DIRECT7SEG1_i
                     , LEDS_i[2]
                     , DOTS_i[2]
                     , DIRECT7SEG2_i
                     , LEDS_i[3]
                     , DOTS_i[3]
                     , DIRECT7SEG3_i
                     , LEDS_i[4]
                     , DOTS_i[4]
                     , DIRECT7SEG4_i
                     , LEDS_i[5]
                     , DOTS_i[5]
                     , DIRECT7SEG5_i
                     , LEDS_i[6]
                     , DOTS_i[6]
                     , DIRECT7SEG6_i
                     , LEDS_i[7]
                     , DOTS_i[7]
                 } ;
                 if ( ENCBIN_XDIRECT_i )
                     MAIN_BUFF[6:0] <= enced_7seg ;
                 else
                     MAIN_BUFF[6:0] <= DIRECT7SEG7_i ;
            end else if (FRAME_REQ_D | ENC_SHIFT)
                 case (FRAME_STATE)
                     S_LOAD :
                        if (ENCBIN_XDIRECT_D) 
                            MAIN_BUFF <=  {
                                  MAIN_BUFF[7*9+7  +:2]
                                , MAIN_BUFF[6*9    +:7]
                                , MAIN_BUFF[6*9+7  +:2]
                                , MAIN_BUFF[5*9    +:7]
                                , MAIN_BUFF[5*9+7  +:2]
                                , MAIN_BUFF[4*9    +:7]
                                , MAIN_BUFF[4*9+7  +:2]
                                , MAIN_BUFF[3*9    +:7]
                                , MAIN_BUFF[3*9+7  +:2]
                                , MAIN_BUFF[2*9    +:7]
                                , MAIN_BUFF[2*9+7  +:2]
                                , MAIN_BUFF[1*9    +:7]
                                , MAIN_BUFF[1*9+7  +:2]
                                , MAIN_BUFF[0*9    +:7]
                                , MAIN_BUFF[0*9+7  +:2]
                                , enced_7seg 
                            } ;
                endcase
            else 
                case (FRAME_STATE)
                       S_LED0L
                     , S_LED1L
                     , S_LED2L
                     , S_LED3L
                     , S_LED4L
                     , S_LED5L
                     , S_LED6L
                     , S_LED7L :
                        case ( BYTE_STATE )
                               S_BIT0
                             , S_BIT1
                             , S_BIT2
                             , S_BIT3
                             , S_BIT4
                             , S_BIT5
                             , S_BIT6
                             , S_BIT7 :
                                 MAIN_BUFF <= {
                                      MAIN_BUFF[0]
                                     , MAIN_BUFF[71:1]
                                 } ;
                         endcase
                       S_LED0H
                     , S_LED1H
                     , S_LED2H
                     , S_LED3H
                     , S_LED4H
                     , S_LED5H
                     , S_LED6H
                     , S_LED7H :
                         case ( BYTE_STATE )
                               S_BIT0 :
                                 MAIN_BUFF <= {
                                       MAIN_BUFF[0]
                                     , MAIN_BUFF[71:1]
                                 } ;
                         endcase
                endcase


    // output BYTE buffer 
    //
    reg [ 7 :0] BYTE_BUF ;
    always @(posedge CK_i or negedge XARST_i) 
        if ( ~ XARST_i )
            BYTE_BUF <= 8'h0 ;
        else if ( EN_CK )
            case ( BYTE_STATE )
                S_LOAD :
                    case ( FRAME_STATE )
                        S_SEND_SET :
                            BYTE_BUF <= 8'h40 ;
                        S_LED_ADR_SET :
                            BYTE_BUF <= 8'hC0 ;
                        S_LEDPWR_SET :
                            BYTE_BUF <= 8'h8F ;
                        S_KEY_ADR_SET :
                            BYTE_BUF <= 8'h42 ;
                          S_LED0L
                        , S_LED1L
                        , S_LED2L
                        , S_LED3L
                        , S_LED4L
                        , S_LED5L
                        , S_LED6L
                        , S_LED7L :
                            BYTE_BUF <= MAIN_BUFF[7:0] ;
                          S_LED0H
                        , S_LED1H
                        , S_LED2H
                        , S_LED3H
                        , S_LED4H
                        , S_LED5H
                        , S_LED6H
                        , S_LED7H :
                            BYTE_BUF <= {7'b0000_000 , MAIN_BUFF[0]} ;
                    endcase
                  S_BIT0
                , S_BIT1
                , S_BIT2
                , S_BIT3
                , S_BIT4
                , S_BIT5
                , S_BIT6
                , S_BIT7 :
                    BYTE_BUF <= {1'b0 , BYTE_BUF[7:1]} ;
        endcase

    assign MOSI_o = BYTE_BUF[0] ;


    reg [ 7 :0] KEYS ;
    always @(posedge CK_i or negedge XARST_i) 
        if ( ~ XARST_i )
            KEYS <= 8'd0 ;
        else if ( EN_SCLK_D )
            case (FRAME_STATE)
                S_KEY0 : 
                    case (BYTE_STATE)
                        S_BIT0 :
                            KEYS[7] <= MISO_i ;
                        S_BIT4 :
                            KEYS[6] <= MISO_i ;
                    endcase
                S_KEY1 : 
                    case (BYTE_STATE)
                        S_BIT0 :
                            KEYS[5] <= MISO_i ;
                        S_BIT4 :
                            KEYS[4] <= MISO_i ;
                    endcase
                S_KEY2 : 
                    case (BYTE_STATE)
                        S_BIT0 :
                            KEYS[3] <= MISO_i ;
                        S_BIT4 :
                            KEYS[2] <= MISO_i ;
                    endcase
                S_KEY3 : 
                    case (BYTE_STATE)
                        S_BIT0 :
                            KEYS[1] <= MISO_i ;
                        S_BIT4 :
                            KEYS[0] <= MISO_i ;
                    endcase
            endcase
    assign KEYS_o = KEYS ;

    assign DB_FRAME_REQ_o = FRAME_REQ ;
    assign DB_EN_CK_o = EN_CK ;
endmodule //TM1638_LED_KEY_DRV()



`timescale 1ns/1ns
module TB_TM1638_LED_KEY_DRV #(
    parameter C_C = 10.0
)(
) ;
    reg     CK  ;
    initial begin
        CK <= 1'b1 ;
        forever begin
            #( C_C /2) ;
            CK <= ~ CK ;
        end
    end
    reg XARST   ;
    initial begin
        XARST <= 1'b1 ;
        #( 0.1 * C_C) ;
            XARST <= 1'b0 ;
        #( 2.1 * C_C) ;
            XARST <= 1'b1 ;
    end

    wire            ENCBIN_XDIRECT_i  ;
    wire            MISO_i          ;
    wire            MOSI            ;
    wire            MOSI_OE         ;
    wire            SCLK_o          ;
    wire            SS_o            ;
    wire    [ 7:0]  KEYS            ;
    wire            DB_FRAME_REQ_o  ;
    wire            DB_EN_SCLK_o    ;
    wire            DB_BUSY_o       ;
    wire            DB_BYTE_BUSY_o  ;
    wire            DB_KEY_STATE_o  ;
    assign ENCBIN_XDIRECT_i = 1'b1 ; //
    TM1638_LED_KEY_DRV #(
          .C_FCK    ( 4096         )// Hz
        , .C_FSCLK  ( 1024             )// Hz
        , .C_FPS    ( 1           )// cycle(Hz)
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
        , .DOTS_i           ( KEYS     )
        , .LEDS_i           ( 8'hFF     )
        , .BIN_DAT_i        ( {
                                  4'hF
                                , 4'hE
                                , 4'hD
                                , 4'hC
                                , 4'hB
                                , 4'hA
                                , 4'h9
                                , 4'h8
                             })
        , .SUP_DIGITS_i     ()
        , .ENCBIN_XDIRECT_i ( ENCBIN_XDIRECT_i)
        , .MISO_i           ( MISO_i        )
        , .MOSI_o           ( MOSI          )
        , .MOSI_OE_o        ( MOSI_OE       )
        , .SCLK_o           ( SCLK_o        )
        , .SS_o             ( SS_o          )
        , .KEYS_o           ( KEYS          )
        , .DB_FRAME_REQ_o   ( DB_FRAME_REQ_o    )
        , .DB_EN_SCLK_o     ( DB_EN_SCLK_o      )
        , .DB_BUSY_o        ( DB_BUSY_o         )
        , .DB_BYTE_BUSY_o   ( DB_BYTE_BUSY_o    )
        , .DB_KEY_STATE_o   ( DB_KEY_STATE_o    )
    ) ;
    
    integer TB_CTR ;
    initial begin
        TB_CTR <= 'd0 ;
        repeat ( 100  ) begin
            repeat ( 100 )
                @(posedge CK) ;
            TB_CTR  <= TB_CTR +1 ;
        end
        $stop ;
    end

endmodule
