// lib/core/protocol/messages.dart
library;
/// AgentMessage types — the content model for everything the chat renders.
/// Derived from packages/ai/src/types.ts `AgentMessage` (desktop reference).
/// Plain Dart — no codegen, zero Flutter dependency (doc 05 §3.1).
// ─── Content blocks ─────────────────────────────────────────────
/// Base type marker shared by all content blocks: "text" | "thinking" | "toolCall" | "image".
abstract class ContentBlock {
  const ContentBlock();
  factory ContentBlock.fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return TextContent(type: 'text', text: raw?.toString() ?? '');
    }
    switch (raw['type'] as String?) {
      case 'thinking':
        return ThinkingContent.fromJson(raw);
      case 'toolCall':
      case 'tool_call':
        return ToolCall.fromJson(raw);
      case 'image':
        return ImageContent.fromJson(raw);
      case 'text':
      default:
        return TextContent.fromJson(raw);
    }
  }
  Map<String, dynamic> toJson();
}
class TextContent extends ContentBlock {
  final String type; // always "text"
  final String text;
  const TextContent({this.type = 'text', required this.text});
  factory TextContent.fromJson(Map<String, dynamic> json) => TextContent(
        type: json['type'] as String? ?? 'text',
        text: json['text'] as String? ?? '',
      );
  @override
  Map<String, dynamic> toJson() => {'type': type, 'text': text};
}
class ThinkingContent extends ContentBlock {
  final String type; // always "thinking"
  final String thinking;
  final Duration? duration; // client-side measured, not from engine
  const ThinkingContent({this.type = 'thinking', required this.thinking, this.duration});
  factory ThinkingContent.fromJson(Map<String, dynamic> json) => ThinkingContent(
        type: json['type'] as String? ?? 'thinking',
        thinking: json['thinking'] as String? ?? '',
      );
  @override
  Map<String, dynamic> toJson() => {'type': type, 'thinking': thinking};
}
class ToolCall extends ContentBlock {
  final String type; // always "toolCall"
  final String id;
  final String name;
  final Map<String, dynamic> arguments; // parsed tool arguments
  const ToolCall({this.type = 'toolCall', required this.id, required this.name, this.arguments = const {}});
  factory ToolCall.fromJson(Map<String, dynamic> json) => ToolCall(
        type: json['type'] as String? ?? 'toolCall',
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        arguments: json['arguments'] is Map<String, dynamic>
            ? json['arguments'] as Map<String, dynamic>
            : const {},
      );
  @override
  Map<String, dynamic> toJson() => {'type': type, 'id': id, 'name': name, 'arguments': arguments};
}
class ImageContent extends ContentBlock {
  final String type; // always "image"
  final String data; // base64, no data: prefix
  final String mimeType;
  const ImageContent({this.type = 'image', required this.data, this.mimeType = 'image/png'});
  factory ImageContent.fromJson(Map<String, dynamic> json) => ImageContent(
        type: json['type'] as String? ?? 'image',
        data: json['data'] as String? ?? '',
        mimeType: json['mimeType'] as String? ?? 'image/png',
      );
  @override
  Map<String, dynamic> toJson() => {'type': type, 'data': data, 'mimeType': mimeType};
}
// ─── AgentMessage roles ──────────────────────────────────────────
abstract class AgentMessage {
  const AgentMessage();
  factory AgentMessage.fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return AssistantMessage(content: const [], timestamp: 0);
    }
    switch (raw['role'] as String?) {
      case 'user':
        return UserMessage.fromJson(raw);
      case 'toolResult':
      case 'tool_result':
        return ToolResultMessage.fromJson(raw);
      case 'assistant':
      default:
        return AssistantMessage.fromJson(raw);
    }
  }
  Map<String, dynamic> toJson();
}
class UserMessage extends AgentMessage {
  final String role; // "user"
  final List<ContentBlock> content; // TextContent | ImageContent
  final int timestamp;
  const UserMessage({this.role = 'user', required this.content, required this.timestamp});
  factory UserMessage.fromJson(Map<String, dynamic> json) => UserMessage(
        role: json['role'] as String? ?? 'user',
        content: (json['content'] as List<dynamic>? ?? []).map(ContentBlock.fromJson).toList(),
        timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      );
  @override
  Map<String, dynamic> toJson() => {'role': role, 'content': content.map((c) => c.toJson()).toList(), 'timestamp': timestamp};
}
class AssistantMessage extends AgentMessage {
  final String role; // "assistant"
  final List<ContentBlock> content; // TextContent | ThinkingContent | ToolCall
  final String? api;
  final String? provider;
  final String? model;
  final Usage? usage;
  final String? stopReason;
  final String? errorMessage;
  final int? retryAfterMs;
  final int timestamp;
  const AssistantMessage({
    this.role = 'assistant',
    required this.content,
    this.api,
    this.provider,
    this.model,
    this.usage,
    this.stopReason,
    this.errorMessage,
    this.retryAfterMs,
    required this.timestamp,
  });
  factory AssistantMessage.fromJson(Map<String, dynamic> json) => AssistantMessage(
        role: json['role'] as String? ?? 'assistant',
        content: (json['content'] as List<dynamic>? ?? []).map(ContentBlock.fromJson).toList(),
        api: json['api'] as String?,
        provider: json['provider'] as String?,
        model: json['model'] as String?,
        usage: json['usage'] is Map<String, dynamic> ? Usage.fromJson(json['usage'] as Map<String, dynamic>) : null,
        stopReason: json['stopReason'] as String?,
        errorMessage: json['errorMessage'] as String?,
        retryAfterMs: (json['retryAfterMs'] as num?)?.toInt(),
        timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      );
  @override
  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content.map((c) => c.toJson()).toList(),
        if (api != null) 'api': api,
        if (provider != null) 'provider': provider,
        if (model != null) 'model': model,
        if (usage != null) 'usage': usage!.toJson(),
        if (stopReason != null) 'stopReason': stopReason,
        if (errorMessage != null) 'errorMessage': errorMessage,
        if (retryAfterMs != null) 'retryAfterMs': retryAfterMs,
        'timestamp': timestamp,
      };
}
class ToolResultMessage extends AgentMessage {
  final String role; // "toolResult"
  final String toolCallId;
  final String toolName;
  final List<ContentBlock> content; // TextContent | ImageContent
  final Object? details;
  final bool isError;
  final int timestamp;
  const ToolResultMessage({
    this.role = 'toolResult',
    required this.toolCallId,
    required this.toolName,
    required this.content,
    this.details,
    required this.isError,
    required this.timestamp,
  });
  factory ToolResultMessage.fromJson(Map<String, dynamic> json) => ToolResultMessage(
        role: json['role'] as String? ?? 'toolResult',
        toolCallId: json['toolCallId'] as String? ?? '',
        toolName: json['toolName'] as String? ?? '',
        content: (json['content'] as List<dynamic>? ?? []).map(ContentBlock.fromJson).toList(),
        details: json['details'],
        isError: json['isError'] as bool? ?? false,
        timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      );
  @override
  Map<String, dynamic> toJson() => {
        'role': role,
        'toolCallId': toolCallId,
        'toolName': toolName,
        'content': content.map((c) => c.toJson()).toList(),
        if (details != null) 'details': details,
        'isError': isError,
        'timestamp': timestamp,
      };
}
// ─── Usage & model info ─────────────────────────────────────────
class Usage {
  final int input;
  final int output;
  final int cacheRead;
  final int cacheWrite;
  final double? costTotal;
  const Usage({required this.input, required this.output, required this.cacheRead, required this.cacheWrite, this.costTotal});
  factory Usage.fromJson(Map<String, dynamic> json) => Usage(
        input: (json['input'] as num?)?.toInt() ?? 0,
        output: (json['output'] as num?)?.toInt() ?? 0,
        cacheRead: (json['cacheRead'] as num?)?.toInt() ?? 0,
        cacheWrite: (json['cacheWrite'] as num?)?.toInt() ?? 0,
        costTotal: (json['costTotal'] as num?)?.toDouble(),
      );
  Map<String, dynamic> toJson() => {
        'input': input,
        'output': output,
        'cacheRead': cacheRead,
        'cacheWrite': cacheWrite,
        if (costTotal != null) 'costTotal': costTotal,
      };
}
class Model {
  final String id;
  final String name;
  final String provider;
  final int? contextWindow;
  final int? maxTokens;
  final bool? reasoning;
  final ModelCost? cost;
  const Model({required this.id, required this.name, required this.provider, this.contextWindow, this.maxTokens, this.reasoning, this.cost});
  factory Model.fromJson(Map<String, dynamic> json) => Model(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        provider: json['provider'] as String? ?? '',
        contextWindow: (json['contextWindow'] as num?)?.toInt(),
        maxTokens: (json['maxTokens'] as num?)?.toInt(),
        reasoning: json['reasoning'] as bool?,
        cost: json['cost'] is Map<String, dynamic> ? ModelCost.fromJson(json['cost'] as Map<String, dynamic>) : null,
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'provider': provider,
        if (contextWindow != null) 'contextWindow': contextWindow,
        if (maxTokens != null) 'maxTokens': maxTokens,
        if (reasoning != null) 'reasoning': reasoning,
        if (cost != null) 'cost': cost!.toJson(),
      };
}
class ModelCost {
  final double? prompt;
  final double? completion;
  final double? cacheRead;
  final double? cacheWrite;
  const ModelCost({this.prompt, this.completion, this.cacheRead, this.cacheWrite});
  factory ModelCost.fromJson(Map<String, dynamic> json) => ModelCost(
        prompt: (json['prompt'] as num?)?.toDouble(),
        completion: (json['completion'] as num?)?.toDouble(),
        cacheRead: (json['cacheRead'] as num?)?.toDouble(),
        cacheWrite: (json['cacheWrite'] as num?)?.toDouble(),
      );
  Map<String, dynamic> toJson() => {
        if (prompt != null) 'prompt': prompt,
        if (completion != null) 'completion': completion,
        if (cacheRead != null) 'cacheRead': cacheRead,
        if (cacheWrite != null) 'cacheWrite': cacheWrite,
      };
}