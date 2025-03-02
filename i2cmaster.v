module wm8731_i2c_master #(
    parameter CLK_FREQ = 50000000,    // Clock hệ thống: 50MHz
    parameter I2C_FREQ = 100000       // I2C clock: 100kHz
)(
    input  wire         clk,         // Clock hệ thống
    input  wire         rst,         // Reset đồng bộ
    input  wire         start,       // Tín hiệu bắt đầu giao dịch
    input  wire [15:0]  config_data, // 16-bit lệnh cấu hình: [15:9] địa chỉ, [8:0] dữ liệu
    output reg          done,        // Giao dịch hoàn thành
    output reg          busy,        // Module đang bận giao dịch
    output reg          i2c_sclk,    // I2C clock (SCLK)
    inout  wire         i2c_sdin     // I2C data line (SDA/SDIN) kiểu open-drain
);

    // Bộ chia clock: DIVIDER = 50MHz / (100kHz * 2) = 250
    localparam integer DIVIDER = CLK_FREQ / (I2C_FREQ * 2);

    // Định nghĩa các trạng thái trong state machine
    localparam STATE_IDLE  = 0;
    localparam STATE_START = 1;
    localparam STATE_SEND  = 2;
    localparam STATE_ACK   = 3;
    localparam STATE_STOP  = 4;
    localparam STATE_DONE  = 5;

    reg [2:0] state;
    reg [4:0] bit_count;       // Đếm từ 15 xuống 0 cho 16-bit dữ liệu
    reg [15:0] shift_reg;      // Thanh dịch chuyển dữ liệu
    reg [15:0] clk_div;        // Bộ đếm chia clock
    reg sdin_out;              // Giá trị sẽ xuất ra trên SDA
    reg sdin_oe;               // Output enable cho SDA: 1 = drive, 0 = high-Z

    // Tri-state buffer cho SDA: nếu sdin_oe = 1, đưa sdin_out ra; nếu 0, để line ở trạng thái high impedance
    assign i2c_sdin = sdin_oe ? sdin_out : 1'bz;

    // Tạo I2C clock (SCLK) từ 50MHz: mỗi nửa chu kỳ I2C kéo dài 250 chu kỳ hệ thống
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            clk_div <= 0;
            i2c_sclk <= 1;  // Idle I2C: SCLK high
        end else begin
            if (clk_div == DIVIDER - 1) begin
                clk_div <= 0;
                i2c_sclk <= ~i2c_sclk;
            end else begin
                clk_div <= clk_div + 1;
            end
        end
    end

    // State machine điều khiển giao dịch I2C
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= STATE_IDLE;
            done       <= 0;
            busy       <= 0;
            sdin_out   <= 1;      // SDA high ở trạng thái idle
            sdin_oe    <= 1;      // Mặc định drive SDA
            shift_reg  <= 0;
            bit_count  <= 0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    done <= 0;
                    if (start) begin
                        busy <= 1;
                        // Chuẩn bị tạo start condition: SDA high, SCLK high
                        sdin_out <= 1;
                        sdin_oe  <= 1;
                        state    <= STATE_START;
                    end
                end

                STATE_START: begin
                    // Khi SCLK high, kéo SDA xuống để tạo start condition
                    if (i2c_sclk == 1) begin
                        sdin_out <= 0; // Start condition: SDA chuyển từ high xuống low
                        // Nạp lệnh cấu hình vào thanh dịch chuyển
                        shift_reg <= config_data;
                        bit_count <= 15;
                        state     <= STATE_SEND;
                    end
                end

                STATE_SEND: begin
                    // Gửi từng bit dữ liệu từ thanh dịch chuyển ra SDA
                    // Chọn cạnh xuống của SCLK (với clk_div = 0) để đảm bảo dữ liệu ổn định
                    if (i2c_sclk == 0 && clk_div == 0) begin
                        sdin_out <= shift_reg[bit_count];
                        if (bit_count == 0)
                            state <= STATE_ACK; // Sau khi gửi hết 16 bit, chuyển sang nhận ACK
                        else
                            bit_count <= bit_count - 1;
                    end
                end

                STATE_ACK: begin
                    // Thả đường SDA (set high-Z) để cho WM8731 gửi ACK
                    sdin_oe <= 0; // Không drive SDA, cho phép slave điều khiển
                    if (i2c_sclk == 0 && clk_div == 0) begin
                        // Ở đây ta có thể sample SDA để kiểm tra ACK, ví dụ đơn giản ta giả định ACK luôn có mặt
                        state <= STATE_STOP;
                    end
                end

                STATE_STOP: begin
                    // Tạo stop condition: khi SCLK high, đưa SDA từ low lên high
                    sdin_oe  <= 1;  // Drive lại SDA
                    sdin_out <= 0;  // Đảm bảo SDA ở mức low trước khi tạo stop condition
                    if (i2c_sclk == 1) begin
                        sdin_out <= 1; // Stop condition: SDA chuyển lên high khi SCLK high
                        state    <= STATE_DONE;
                    end
                end

                STATE_DONE: begin
                    busy  <= 0;
                    done  <= 1;
                    state <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
