export const setProperty = (key) => (value) => (node) => () => {
  node[key] = value;
};

export const unsafeRefEq = (a) => (b) => a === b;

const fps = 1e3 / 60;
let channel = null;
let frameDeadline = 0;
let pendingCallback = null;
const deadline = { timeRemaining: () => frameDeadline - performance.now() };

export const scheduleWork = (callback) => () => {
  // Created lazily so that merely importing this module (e.g. in Node tests)
  // does not open a port that keeps the process alive.
  if (channel === null) {
    channel = new MessageChannel();
    channel.port2.onmessage = () => pendingCallback(deadline)();
  }
  requestAnimationFrame((frameTime) => {
    frameDeadline = frameTime + fps;
    pendingCallback = callback;
    channel.port1.postMessage(null);
  });
};
