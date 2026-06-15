import '../rust/api.dart';

/// Callback surface for [OrchestrateEvent] stream handling in host apps.
///
/// Defined in rope_editor so dispatch uses the same library as freezed codegen.
typedef OrchestrateEventCallbacks = ({
  void Function(String text) onThinking,
  void Function(String delta) onEditDelta,
  void Function(List<FileReference> files, String message) onContextWindowUpdate,
  void Function(AgentContextBudget budget) onContextBudgetUpdate,
  void Function(AgentResponse response) onComplete,
  void Function(String message) onError,
});

extension OrchestrateEventDispatch on OrchestrateEvent {
  void dispatch(OrchestrateEventCallbacks callbacks) {
    when(
      thinking: callbacks.onThinking,
      editDelta: callbacks.onEditDelta,
      contextWindowUpdate: callbacks.onContextWindowUpdate,
      contextBudgetUpdate: callbacks.onContextBudgetUpdate,
      complete: callbacks.onComplete,
      error: callbacks.onError,
    );
  }
}
