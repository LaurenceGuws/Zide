const std = @import("std");

pub const Metrics = struct {
    frames: u64,
    redraws: u64,
    last_frame_time: f64,
    frame_ms_avg: f64,
    draw_ms_avg: f64,
    input_latency_ms_avg: f64,
    input_latency_ms_max: f64,
    last_input_time: ?f64,
    alpha: f64,

    pub fn init() Metrics {
        return .{
            .frames = 0,
            .redraws = 0,
            .last_frame_time = 0,
            .frame_ms_avg = 0,
            .draw_ms_avg = 0,
            .input_latency_ms_avg = 0,
            .input_latency_ms_max = 0,
            .last_input_time = null,
            .alpha = 0.1,
        };
    }

    pub fn beginFrame(self: *Metrics, now: f64) void {
        if (self.last_frame_time > 0) {
            const dt_ms = (now - self.last_frame_time) * 1000.0;
            self.frame_ms_avg = ema(self.frame_ms_avg, dt_ms, self.alpha);
        }
        self.last_frame_time = now;
        self.frames += 1;
    }

    pub fn noteInput(self: *Metrics, now: f64) void {
        self.last_input_time = now;
    }

    pub fn recordDraw(self: *Metrics, start: f64, end: f64) void {
        self.redraws += 1;
        const draw_ms = (end - start) * 1000.0;
        self.draw_ms_avg = ema(self.draw_ms_avg, draw_ms, self.alpha);

        if (self.last_input_time) |t| {
            const latency_ms = (end - t) * 1000.0;
            self.input_latency_ms_avg = ema(self.input_latency_ms_avg, latency_ms, self.alpha);
            if (latency_ms > self.input_latency_ms_max) {
                self.input_latency_ms_max = latency_ms;
            }
            self.last_input_time = null;
        }
    }

    fn ema(prev: f64, sample: f64, alpha: f64) f64 {
        if (prev == 0) return sample;
        return prev + alpha * (sample - prev);
    }
};
