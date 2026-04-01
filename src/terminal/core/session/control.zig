pub fn lock(self: anytype) void {
    self.control.state_mutex.lock();
}

pub fn tryLock(self: anytype) bool {
    return self.control.state_mutex.tryLock();
}

pub fn unlock(self: anytype) void {
    self.control.state_mutex.unlock();
}
