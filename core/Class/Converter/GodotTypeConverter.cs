using Godot;
using System.Collections.Generic;

/// <summary>
/// 广义转换工具，负责 Godot 字典与 C# 内部字典（键为 StringName，值为 Variant）的双向转换。
/// 值类型统一使用 Variant，避免拆箱。
/// </summary>
public static class GodotTypeConverter
{
	/// <summary>
	/// 将 Godot.Collections.Dictionary 转换为 C# 内部字典（键 StringName，值 Variant）。
	/// 键强制转为 StringName，值原样保留。
	/// </summary>
	public static Dictionary<StringName, Variant> ToInnerDictionary(Godot.Collections.Dictionary godotDict)
	{
		var inner = new Dictionary<StringName, Variant>();
		foreach (Variant key in godotDict.Keys)
		{
			StringName stringKey = key.AsStringName();
			Variant val = godotDict[key];
			inner[stringKey] = val;
		}
		return inner;
	}

	/// <summary>
	/// 将 C# 内部字典转换为 Godot.Collections.Dictionary<StringName, Variant>。
	/// </summary>
	public static Godot.Collections.Dictionary<StringName, Variant> ToGodotDictionary(Dictionary<StringName, Variant> innerDict)
	{
		// 必须按此方式构造，否则 GDScript 会视为未指定类型的 Dictionary
		Godot.Collections.Dictionary<StringName, Variant> godotDict = new Godot.Collections.Dictionary<StringName, Variant>();
		foreach (KeyValuePair<StringName, Variant> kvp in innerDict)
		{
			godotDict[(StringName)kvp.Key] = kvp.Value;
		}
		return godotDict;
	}
}
