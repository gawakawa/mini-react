export const setProperty = (key) => (value) => (node) => () => {
  node[key] = value;
};
