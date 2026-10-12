export const setProperty = (key) => (value) => (node) => () => {
  node[key] = value;
};

export const unsafeRefEq = (a) => (b) => a === b;
