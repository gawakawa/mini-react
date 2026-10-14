import * as MR from "../output/MiniReact/index.js";
import { fst, snd } from "../output/Data.Tuple/index.js";

export const Fragment = Symbol("Fragment");

// The same JS component must map to the same renderer, because
// reconcile compares renderers by reference (sameComponent).
const renderers = new WeakMap();
const toRenderer = (fn) => {
  let r = renderers.get(fn);
  if (r === undefined) {
    r = (props) => () => fn(props);
    renderers.set(fn, r);
  }
  return r;
};

const toChildren = (children) =>
  children
    .flat(Infinity)
    .filter((c) => c !== null && c !== undefined && typeof c !== "boolean")
    .map((c) => (typeof c === "object" ? c : MR.HostText.create(String(c))));

const toProps = (props) =>
  Object.entries(props ?? {}).flatMap(([key, value]) =>
    key === "key"
      ? []
      : key.startsWith("on")
        ? [MR.Listener.create(key.slice(2).toLowerCase())(value)]
        : [MR.Property.create(key)(String(value))],
  );

export const createElement = (type, props, ...children) => {
  const kids = toChildren(children);
  if (type === Fragment) return MR.Fragment.create(kids);
  if (typeof type === "function") {
    return MR.component(toRenderer(type))({ ...props, children: kids });
  }
  return MR.HostComponent.create(type)(toProps(props))(kids);
};

export const useState = (initial) => {
  const t = MR.useState(initial)();
  return [fst(t), (value) => snd(t)(value)()];
};

export const render = (element, container) => MR.render(element)(container)();
