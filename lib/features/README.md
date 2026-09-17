`context.read` once, plus `SignalBuilder` to rebuild off the signals it reads.
The page imports no container and no repository; provider creates the view model
once per mount and disposes it through its `dispose:` callback (factory scope —
the container does not).

- A view model that finishes loading after its view is gone must stay silent:
  writing to a disposed signal throws, so the disposed flag guards every write and
  the signals go down with the view model. See the disposed flag in
  `posts/presentation/view_models/post_view_model.dart`.
- How the state is shaped, and the traps in it: [Screen state](../../docs/architecture.md#screen-state).
- Keep the feature `const`. `KaiselModuleMount` rebuilds its router when the
  module instance changes, so a fresh instance per build would silently drop the
  feature's navigation state.
