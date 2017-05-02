// ‘û“ü‚è
// SUBREG_TIM_DIV.v
//      SUBREG_TIM_DIV()
//
// subRegulation timing clock divider
//  
//  This  module generate PLSE_N_i clock H pluse to EN_CK_o in PERIOD_i clock
//     most reguler time split, HLHLHL pluse
// for example :
//   PRERIOD_i==3, PULSE_N=2
//    012345012345
//    HLHHLHHLHHLH...
// for use :
//   this module is better in low jitter than PWM 
//
///2017-05-02tu :1st 

module SUBREG_TIM_DIV #(
      parameter C_PERIOD_W = 31
)(
      input                             CK_i
    , input tri1                        XARST_i
    , input tri0    [C_PERIOD_W-1 :0]   PERIOD_i
    , input tri0    [C_PERIOD_W-1 :0]   PULSE_N_i
    , output                            EN_CK_o
) ;
    function time log2;             //time is reg unsigned [63:0]
        input time value ;
    begin
        value = value-1;
        for (log2=0; value>0; log2=log2+1)
            value = value>>1;
    end endfunction
    
    
    reg  signed [C_PERIOD_W:0] DIV_CTR ;
    wire signed [C_PERIOD_W:0] DIV_CTR_a ;
    assign DIV_CTR_a = 
        DIV_CTR 
        - $unsigned(PULSE_N_i) 
        + $unsigned(EN_CK_o ? PERIOD_i : 'd0)
    ;
    always @(posedge CK_i or negedge XARST_i)
        if ( ~ XARST_i)
            DIV_CTR <= 'd0 ;
        else
            DIV_CTR <= DIV_CTR_a ;
    assign EN_CK_o = DIV_CTR[C_PERIOD_W] ; //sign
endmodule //SUBREG_TIM_DIV





`timescale 1ns/1ns
module TB_SUBREG_TIM_DIV #(
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

    assign ENCBIN_XDIRECT_i = 1'b1 ; //
    SUBREG_TIM_DIV #(
          .C_PERIOD_W   ( 3   )// Hz
    ) SUBREG_TIM_DIV (
          .CK_i             ( CK        )
        , .XARST_i          ( XARST     )
        , .PERIOD_i         ( 7         )
        , .PULSE_N_i        ( 3         )
        , .EN_CK_o          ( EN_CK_o   )
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

    integer CK_CTR ;
    always @ (posedge CK or negedge XARST)
        if ( ~ XARST)
            CK_CTR <= 'd0 ;
        else if ( EN_CK_o )
            CK_CTR <= CK_CTR + 'd1 ;
endmodule
