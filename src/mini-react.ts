type ComponentFunction = {
  new (props: Record<string, unknown>): Component;
  (props: Record<string, unknown>): VirtualElement | string;
};

type VirtualElementType = ComponentFunction | string;

type VirtualElementProps = {
  children?: VirtualElement[];
  [propName: string]: unknown;
};

type VirtualElement = {
  type: VirtualElementType;
  props: VirtualElementProps;
};

type FiberNodeDOM = Element | Text | null | undefined;

// deno-lint-ignore no-explicit-any
type FiberNode<S = any> = VirtualElement & {
  alternate: FiberNode<S> | null;
  dom?: FiberNodeDOM;
  effectTag?: string;
  child?: FiberNode;
  return?: FiberNode;
  sibling?: FiberNode;
  hooks?: {
    state: S;
    queue: S[];
  }[];
};

abstract class Component {
  props: Record<string, unknown>;
  abstract state: unknown;
  abstract setState: (value: unknown) => void;
  abstract render: () => VirtualElement;

  constructor(props: Record<string, unknown>) {
    this.props = props;
  }

  static REACT_COMPONENT = true;
}

((global: Window) => {
  const id = 1;
  const fps = 1e3 / 60;
  let frameDeadline: number;
  let pendingCallback: IdleRequestCallback;
  const channel = new MessageChannel();
  const timeRemaining = () => frameDeadline - globalThis.performance.now();

  const deadline = {
    didTimeout: false,
    timeRemaining,
  };

  channel.port2.onmessage = () => {
    if (typeof pendingCallback === 'function') {
      pendingCallback(deadline);
    }
  };

  global.requestIdleCallback = (callback: IdleRequestCallback) => {
    global.requestAnimationFrame((frameTime) => {
      frameDeadline = frameTime + fps;
      pendingCallback = callback;
      channel.port1.postMessage(null);
    });
    return id;
  };
})(window);

const commitRoot = () => {
  const findParentFiber = (fiberNode?: FiberNode) => {
    if (fiberNode) {
      let parentFiber = fiberNode.return;
      while (parentFiber && !parentFiber.dom) {
        parentFiber = parentFiber.return;
      }
      return parentFiber;
    }

    return null;
  };

  const commitDeletion = (
    parentDOM: FiberNodeDOM,
    DOM: NonNullable<FiberNodeDOM>,
  ) => {
    if (isDef(parentDOM)) {
      parentDOM.removeChild(DOM);
    }
  };

  const commitReplacement = (
    parentDOM: FiberNodeDOM,
    DOM: NonNullable<FiberNodeDOM>,
  ) => {
    if (isDef(parentDOM)) {
      parentDOM.appendChild(DOM);
    }
  };

  const commitWork = (fiberNode?: FiberNode) => {
    if (fiberNode) {
      if (fiberNode.dom) {
        const parentFiber = findParentFiber(fiberNode);
        const parentDOM = parentFiber?.dom;

        switch (fiberNode.effectTag) {
          case 'UPDATE':
            updateDOM(
              fiberNode.dom,
              fiberNode.alternate ? fiberNode.alternate.props : {},
              fiberNode.props,
            );
            break;

          case 'REPLACEMENT':
            commitReplacement(parentDOM, fiberNode.dom);
            break;

          default:
            break;
        }
      }

      commitWork(fiberNode.child);
      commitWork(fiberNode.sibling);
    }
  };

  deletions.map((deletion) => {
    if (deletion.dom) {
      const parentFiber = findParentFiber(deletion);
      commitDeletion(parentFiber?.dom, deletion.dom);
    }
  });

  if (wipRoot !== null) {
    commitWork(wipRoot.child);
    currentRoot = wipRoot;
  }

  wipRoot = null;
};

const reconcileChildren = (
  fiberNode: FiberNode,
  elements: VirtualElement[] = [],
) => {
  let index = 0;
  let oldFiberNode: FiberNode | undefined = void 0;
  let prevSibling: FiberNode | undefined = void 0;
  const virtualElements = elements.flat(Infinity);

  if (fiberNode.alternate?.child) {
    oldFiberNode = fiberNode.alternate.child;
  }

  while (
    index < virtualElements.length ||
    typeof oldFiberNode !== 'undefined'
  ) {
    const virtualElement = virtualElements[index];
    let newFiber: FiberNode | undefined = void 0;

    const isSameType = Boolean(
      oldFiberNode &&
        virtualElement &&
        oldFiberNode.type === virtualElement.type,
    );

    if (isSameType && oldFiberNode) {
      newFiber = {
        type: oldFiberNode.type,
        dom: oldFiberNode.dom,
        alternate: oldFiberNode,
        props: virtualElement.props,
        return: fiberNode,
        effectTag: 'UPDATE',
      };
    }
    if (!isSameType && Boolean(virtualElement)) {
      newFiber = {
        type: virtualElement.type,
        dom: null,
        alternate: null,
        props: virtualElement.props,
        return: fiberNode,
        effectTag: 'REPLACEMENT',
      };
    }
    if (!isSameType && oldFiberNode) {
      deletions.push(oldFiberNode);
    }

    if (oldFiberNode) {
      oldFiberNode = oldFiberNode.sibling;
    }

    if (index === 0) {
      fiberNode.child = newFiber;
    } else if (typeof prevSibling !== 'undefined') {
      prevSibling.sibling = newFiber;
    }

    prevSibling = newFiber;
    index += 1;
  }
};

const Fragment = Symbol.for('react.fragment');

const performUnitOfWork = (fiberNode: FiberNode): FiberNode | null => {
  const { type } = fiberNode;
  switch (typeof type) {
    case 'function': {
      wipFiber = fiberNode;
      wipFiber.hooks = [];
      hookIndex = 0;
      let children: ReturnType<ComponentFunction>;

      if (Object.getPrototypeOf(type).REACT_COMPONENT) {
        const C = type;
        const component = new C(fiberNode.props);
        const [state, setState] = useState(component.state);
        component.props = fiberNode.props;
        component.state = state;
        component.setState = setState;
        children = component.render.bind(component)();
      } else {
        children = type(fiberNode.props);
      }
      reconcileChildren(fiberNode, [
        isVirtualElement(children)
          ? children
          : createTextElement(String(children)),
      ]);
      break;
    }

    case 'number':
    case 'string':
      if (!fiberNode.dom) {
        fiberNode.dom = createDOM(fiberNode);
      }
      reconcileChildren(fiberNode, fiberNode.props.children);
      break;

    case 'symbol':
      if (type === Fragment) {
        reconcileChildren(fiberNode, fiberNode.props.children);
      }
      break;

    default:
      if (typeof fiberNode.props !== 'undefined') {
        reconcileChildren(fiberNode, fiberNode.props.children);
      }
      break;
  }

  if (fiberNode.child) {
    return fiberNode.child;
  }

  let nextFiberNode: FiberNode | undefined = fiberNode;

  while (typeof nextFiberNode !== 'undefined') {
    if (nextFiberNode.sibling) {
      return nextFiberNode.sibling;
    }

    nextFiberNode = nextFiberNode.return;
  }

  return null;
};

const workLoop: IdleRequestCallback = (deadline) => {
  while (nextUnitOfWork && deadline.timeRemaining() > 1) {
    nextUnitOfWork = performUnitOfWork(nextUnitOfWork);
  }

  if (!nextUnitOfWork && wipRoot) {
    commitRoot();
  }

  globalThis.requestIdleCallback(workLoop);
};

const isVirtualElement = (e: unknown): e is VirtualElement =>
  typeof e === 'object';

const createTextElement = (text: string): VirtualElement => ({
  type: 'TEXT',
  props: {
    nodeValue: text,
  },
});

const createElement = (
  type: VirtualElementType,
  props: Record<string, unknown> = {},
  ...child: (unknown | VirtualElement)[]
): VirtualElement => {
  const children = child.map((c) =>
    isVirtualElement(c) ? c : createTextElement(String(c))
  );

  return {
    type,
    props: {
      ...props,
      children,
    },
  };
};

const updateDOM = (
  DOM: NonNullable<FiberNodeDOM>,
  prevProps: VirtualElementProps,
  nextProps: VirtualElementProps,
) => {
  const defaultPropKeys = 'children';

  Object.entries(prevProps).map(([removePropKey, removePropValue]) => {
    if (removePropKey.startsWith('on')) {
      DOM.removeEventListener(
        removePropKey.substring(2).toLowerCase(),
        removePropValue as EventListenerOrEventListenerObject,
      );
    } else if (removePropKey !== defaultPropKeys) {
      // deno-lint-ignore no-explicit-any
      (DOM as any)[removePropKey] = '';
    }
  });

  Object.entries(nextProps).map(([addPropKey, addPropValue]) => {
    if (addPropKey.startsWith('on')) {
      DOM.addEventListener(
        addPropKey.substring(2).toLowerCase(),
        addPropValue as EventListenerOrEventListenerObject,
      );
    } else if (addPropKey !== defaultPropKeys) {
      // deno-lint-ignore no-explicit-any
      (DOM as any)[addPropKey] = addPropValue;
    }
  });
};

const createDOM = (fiberNode: FiberNode): FiberNodeDOM => {
  const { type, props } = fiberNode;
  const DOM: FiberNodeDOM = type === 'TEXT'
    ? document.createTextNode('')
    : typeof type === 'string'
    ? document.createElement(type)
    : null;

  if (DOM !== null) {
    updateDOM(DOM, {}, props);
  }

  return DOM;
};

let wipRoot: FiberNode | null = null;
let nextUnitOfWork: FiberNode | null = null;
let currentRoot: FiberNode | null = null;
let deletions: FiberNode[] = [];
let wipFiber: FiberNode;
let hookIndex = 0;

const render = (element: VirtualElement, container: Element) => {
  currentRoot = null;
  wipRoot = {
    type: 'div',
    dom: container,
    props: {
      children: [{ ...element }],
    },
    alternate: currentRoot,
  };
  nextUnitOfWork = wipRoot;
  deletions = [];
};

const isDef = <T>(param: T): param is NonNullable<T> =>
  param !== void 0 && param !== null;

const isPlainObject = (val: unknown): val is Record<string, unknown> =>
  Object.prototype.toString.call(val) === '[object Object]' &&
  [Object.prototype, null].includes(Object.getPrototypeOf(val));

function useState<S>(initState: S): [S, (value: S) => void] {
  const fiberNode: FiberNode<S> = wipFiber;
  const hook: {
    state: S;
    queue: S[];
  } = fiberNode?.alternate?.hooks ? fiberNode.alternate.hooks[hookIndex] : {
    state: initState,
    queue: [],
  };

  while (hook.queue.length) {
    let newState = hook.queue.shift();
    if (isPlainObject(hook.state) && isPlainObject(newState)) {
      newState = { ...hook.state, ...newState };
    }
    if (isDef(newState)) {
      hook.state = newState;
    }
  }

  if (typeof fiberNode.hooks === 'undefined') {
    fiberNode.hooks = [];
  }

  fiberNode.hooks.push(hook);
  hookIndex += 1;

  const setState = (value: S) => {
    hook.queue.push(value);
    if (currentRoot) {
      wipRoot = {
        type: currentRoot.type,
        dom: currentRoot.dom,
        props: currentRoot.props,
        alternate: currentRoot,
      };
      nextUnitOfWork = wipRoot;
      deletions = [];
      currentRoot = null;
    }
  };

  return [hook.state, setState];
}

void (function main() {
  globalThis.requestIdleCallback(workLoop);
})();

export { Component, createElement, Fragment, render, useState };

export default {
  createElement,
  render,
  useState,
  Component,
  Fragment,
};
