`timescale 1ns/1ps

module tb_wm8731_i2c_master();

  // Định nghĩa các tham số giống module chính
  localparam CLK_FREQ = 50000000;
  localparam I2C_FREQ = 100000;  // 100 kHz

  reg         clk;
  reg         rst;
  reg         start;
  reg [15:0]  config_data;
  wire        done;
  wire        busy;
  wire        i2c_sclk;
  wire        i2c_sdin;  // Dòng bidirectional, do module tự drive khi cần

  // Khởi tạo module I2C master (DUT)
  wm8731_i2c_master #(
      .CLK_FREQ(CLK_FREQ),
      .I2C_FREQ(I2C_FREQ)
  ) uut (
      .clk(clk),
      .rst(rst),
      .start(start),
      .config_data(config_data),
      .done(done),
      .busy(busy),
      .i2c_sclk(i2c_sclk),
      .i2c_sdin(i2c_sdin)
  );

  // Tạo clock 50MHz: chu kỳ 20 ns
  initial begin
    clk = 0;
    forever #10 clk = ~clk;
  end

  // Sinh tín hiệu reset
  initial begin
    rst = 1;
    #100;
    rst = 0;
  end

  // Sinh tín hiệu start và giá trị lệnh cấu hình mẫu
  initial begin
    start = 0;
    config_data = 16'hA5A5;  // Ví dụ: 16'hA5A5 làm lệnh cấu hình
    #200;                   // Đợi sau reset, đảm bảo hệ thống ổn định
    start = 1;
    #20;
    start = 0;
  end

  // In ra các tín hiệu để theo dõi quá trình giao dịch I2C
  initial begin
    $monitor("Time: %0t ns | start: %b | done: %b | busy: %b | i2c_sclk: %b | i2c_sdin: %b", 
              $time, start, done, busy, i2c_sclk, i2c_sdin);
  end

  // Kết thúc simulation sau khoảng thời gian đủ dài để kiểm tra giao dịch
  initial begin
    #10000;
    $finish;
  end

endmodule
