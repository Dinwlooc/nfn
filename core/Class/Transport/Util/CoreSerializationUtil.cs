using Godot;
using System;
using System.Text;
using System.Collections.Generic;

/// <summary>
/// 核心序列化工具。
/// 提供高效的二进制序列化/反序列化，支持基本类型、数组、字典（分组优化），
/// 以及两种 Variant 处理方式：
///   - WriteVariantValue/ReadVariantValue：不带类型标记，仅读写值（需外部提供类型）
///   - WriteGeneric/ReadGeneric：自描述格式，读写类型标记 + 值
/// 注意：本工具不对 Vector2、Vector3 等几何类型做特殊兼容，请使用引擎原生序列化或自行扩展。
/// </summary>
public static class CoreSerializationUtil
{
	// ============================================================
	//  基本类型读写（PascalCase）
	// ============================================================

	public static void WriteInt(StreamPeerBuffer buffer, long value) => WriteVarint(buffer, value);
	public static long ReadInt(StreamPeerBuffer buffer) => ReadVarint(buffer);

	public static void WriteFloat(StreamPeerBuffer buffer, double value) => buffer.PutDouble(value);
	public static double ReadFloat(StreamPeerBuffer buffer) => buffer.GetDouble();

	public static void WriteBool(StreamPeerBuffer buffer, bool value) => buffer.PutU8((byte)(value ? 1 : 0));
	public static bool ReadBool(StreamPeerBuffer buffer) => buffer.GetU8() != 0;

	public static void WriteString(StreamPeerBuffer buffer, string value)
	{
		byte[] utf8 = Encoding.UTF8.GetBytes(value);
		WriteVarint(buffer, utf8.Length);
		if (utf8.Length > 0)
			buffer.PutData(utf8);
	}
	public static string ReadString(StreamPeerBuffer buffer)
	{
		int len = (int)ReadVarint(buffer);
		return len == 0 ? "" : buffer.GetUtf8String(len);
	}

	public static void WriteStringName(StreamPeerBuffer buffer, StringName value) =>
		WriteString(buffer, value.ToString());
	public static StringName ReadStringName(StreamPeerBuffer buffer) =>
		new StringName(ReadString(buffer));

	public static void WriteByteArray(StreamPeerBuffer buffer, byte[] array)
	{
		WriteVarint(buffer, array.Length);
		if (array.Length > 0)
			buffer.PutData(array);
	}
	public static byte[] ReadByteArray(StreamPeerBuffer buffer)
	{
		int size = (int)ReadVarint(buffer);
		if (size == 0) return Array.Empty<byte>();
		Godot.Collections.Array result = buffer.GetData(size);
		if (result.Count < 2) return Array.Empty<byte>();
		return result[1].AsByteArray();
	}

	public static void WriteInt32Array(StreamPeerBuffer buffer, int[] array)
	{
		WriteVarint(buffer, array.Length);
		foreach (int v in array)
			WriteVarint(buffer, v);
	}
	public static int[] ReadInt32Array(StreamPeerBuffer buffer)
	{
		int size = (int)ReadVarint(buffer);
		int[] arr = new int[size];
		for (int i = 0; i < size; i++)
			arr[i] = (int)ReadVarint(buffer);
		return arr;
	}

	public static void WriteInt64Array(StreamPeerBuffer buffer, long[] array)
	{
		WriteVarint(buffer, array.Length);
		foreach (long v in array)
			WriteVarint(buffer, v);
	}
	public static long[] ReadInt64Array(StreamPeerBuffer buffer)
	{
		int size = (int)ReadVarint(buffer);
		long[] arr = new long[size];
		for (int i = 0; i < size; i++)
			arr[i] = ReadVarint(buffer);
		return arr;
	}

	// ---------- 字典（分组优化） ----------
	public static void WriteDictionary(StreamPeerBuffer buffer, Dictionary<StringName, Variant> dict) =>
		WriteDictionaryInner(buffer, dict);
	public static Dictionary<StringName, Variant> ReadDictionary(StreamPeerBuffer buffer) =>
		ReadDictionaryInner(buffer);

	// ---------- 不带类型标记的 Variant 值读写（自定义优化） ----------
	/// <summary>写入 Variant 的值部分（不写类型标记），需要外部提供类型信息。</summary>
	public static void WriteVariantValue(StreamPeerBuffer buffer, Variant value)
	{
		switch (value.VariantType)
		{
			case Variant.Type.String:       WriteString(buffer, value.AsString()); break;
			case Variant.Type.Int:          WriteInt(buffer, value.AsInt64()); break;
			case Variant.Type.StringName:   WriteStringName(buffer, value.AsStringName()); break;
			case Variant.Type.Float:        WriteFloat(buffer, value.AsDouble()); break;
			case Variant.Type.Bool:         WriteBool(buffer, value.AsBool()); break;
			case Variant.Type.PackedByteArray: WriteByteArray(buffer, value.AsByteArray()); break;
			case Variant.Type.PackedInt32Array: WriteInt32Array(buffer, value.AsInt32Array()); break;
			case Variant.Type.PackedInt64Array: WriteInt64Array(buffer, value.AsInt64Array()); break;
			case Variant.Type.Dictionary:
				var godotDict = value.AsGodotDictionary();
				var innerDict = GodotTypeConverter.ToInnerDictionary(godotDict);
				WriteDictionary(buffer, innerDict);
				break;
			case Variant.Type.Nil:
				throw new NotSupportedException("Nil values are not supported.");
			default:
				// 不支持的类型回退到引擎原生（但失去优化）
				buffer.PutVar(value);
				break;
		}
	}

	/// <summary>读取 Variant 的值部分（根据给定的类型标记）。</summary>
	public static Variant ReadVariantValue(StreamPeerBuffer buffer, int typeId)
	{
		switch ((Variant.Type)typeId)
		{
			case Variant.Type.String:       return ReadString(buffer);
			case Variant.Type.Int:          return ReadInt(buffer);
			case Variant.Type.StringName:   return ReadStringName(buffer);
			case Variant.Type.Float:        return ReadFloat(buffer);
			case Variant.Type.Bool:         return ReadBool(buffer);
			case Variant.Type.PackedByteArray: return ReadByteArray(buffer);
			case Variant.Type.PackedInt32Array: return ReadInt32Array(buffer);
			case Variant.Type.PackedInt64Array: return ReadInt64Array(buffer);
			case Variant.Type.Dictionary:
				var innerDict = ReadDictionary(buffer);
				return Variant.From(GodotTypeConverter.ToGodotDictionary(innerDict));
			case Variant.Type.Nil:
				throw new NotSupportedException("Nil type cannot be read.");
			default:
				return buffer.GetVar(); // fallback
		}
	}

	// ---------- 带类型标记的自描述 Variant 读写 ----------
	/// <summary>写入类型标记 + 值（自描述格式）。</summary>
	public static void WriteGeneric(StreamPeerBuffer buffer, Variant value)
	{
		if (value.VariantType == Variant.Type.Nil)
			throw new NotSupportedException("Nil values are not supported.");
		WriteVarint(buffer, (int)value.VariantType);
		WriteVariantValue(buffer, value);
	}

	/// <summary>读取类型标记 + 值（自描述格式）。</summary>
	public static Variant ReadGeneric(StreamPeerBuffer buffer)
	{
		int typeId = (int)ReadVarint(buffer);
		return ReadVariantValue(buffer, typeId);
	}

	// ============================================================
	//  私有辅助方法（camelCase）
	// ============================================================

	private static void WriteVarintUnsigned(StreamPeerBuffer buffer, ulong value)
	{
		while (value >= 0x80)
		{
			buffer.PutU8((byte)((value & 0x7F) | 0x80));
			value >>= 7;
		}
		buffer.PutU8((byte)value);
	}

	private static ulong ReadVarintUnsigned(StreamPeerBuffer buffer)
	{
		ulong result = 0;
		int shift = 0;
		byte b;
		do
		{
			b = buffer.GetU8();
			result |= (ulong)(b & 0x7F) << shift;
			shift += 7;
		} while ((b & 0x80) != 0);
		return result;
	}

	private static void WriteVarint(StreamPeerBuffer buffer, long value)
	{
		unchecked
		{
			ulong zigzag = (ulong)((value << 1) ^ (value >> 63));
			WriteVarintUnsigned(buffer, zigzag);
		}
	}

	private static long ReadVarint(StreamPeerBuffer buffer)
	{
		ulong zigzag = ReadVarintUnsigned(buffer);
		long decoded = (long)((zigzag >> 1) ^ (ulong)(-(long)(zigzag & 1)));
		return decoded;
	}

	// ============================================================
	//  字典分组优化内部实现
	// ============================================================

	private static void WriteDictionaryInner(StreamPeerBuffer buffer, Dictionary<StringName, Variant> dict)
	{
		int total = dict.Count;
		WriteVarint(buffer, total);
		if (total == 0) return;

		if (total <= 5)
		{
			WriteSmallDictEntries(buffer, dict);
			return;
		}

		var groups = ClassifyDictEntries(dict);
		WriteGroupInt(buffer, groups[0]);
		WriteGroupFloat(buffer, groups[1]);
		WriteGroupString(buffer, groups[2]);
		WriteGroupBool(buffer, groups[3]);
		WriteGroupOther(buffer, groups[4]);
	}

	private static Dictionary<StringName, Variant> ReadDictionaryInner(StreamPeerBuffer buffer)
	{
		int total = (int)ReadVarint(buffer);
		if (total == 0) return new Dictionary<StringName, Variant>();

		if (total <= 5)
			return ReadSmallDictEntries(buffer, total);

		var dict = new Dictionary<StringName, Variant>();
		int processed = 0;
		processed += ReadGroupInt(buffer, dict);
		processed += ReadGroupFloat(buffer, dict);
		processed += ReadGroupString(buffer, dict);
		processed += ReadGroupBool(buffer, dict);
		int otherCount = total - processed;
		if (otherCount > 0)
			ReadGroupOther(buffer, dict, otherCount);
		return dict;
	}

	private static void WriteSmallDictEntries(StreamPeerBuffer buffer, Dictionary<StringName, Variant> dict)
	{
		foreach (KeyValuePair<StringName, Variant> kvp in dict)
		{
			WriteString(buffer, kvp.Key.ToString());
			WriteGeneric(buffer, kvp.Value); // 使用自描述格式（内含类型标记）
		}
	}

	private static Dictionary<StringName, Variant> ReadSmallDictEntries(StreamPeerBuffer buffer, int count)
	{
		var dict = new Dictionary<StringName, Variant>();
		for (int i = 0; i < count; i++)
		{
			string keyStr = ReadString(buffer);
			StringName key = new StringName(keyStr);
			Variant val = ReadGeneric(buffer);
			dict[key] = val;
		}
		return dict;
	}

	private static Dictionary<StringName, Variant>[] ClassifyDictEntries(Dictionary<StringName, Variant> dict)
	{
		var groups = new Dictionary<StringName, Variant>[5];
		for (int i = 0; i < 5; i++)
			groups[i] = new Dictionary<StringName, Variant>();

		foreach (KeyValuePair<StringName, Variant> kvp in dict)
		{
			Variant val = kvp.Value;
			switch (val.VariantType)
			{
				case Variant.Type.Int:    groups[0][kvp.Key] = val; break;
				case Variant.Type.Float:  groups[1][kvp.Key] = val; break;
				case Variant.Type.String: groups[2][kvp.Key] = val; break;
				case Variant.Type.Bool:   groups[3][kvp.Key] = val; break;
				default:                  groups[4][kvp.Key] = val; break;
			}
		}
		return groups;
	}

	private static void WriteGroupInt(StreamPeerBuffer buffer, Dictionary<StringName, Variant> group)
	{
		WriteVarint(buffer, group.Count);
		foreach (KeyValuePair<StringName, Variant> kvp in group)
		{
			WriteString(buffer, kvp.Key.ToString());
			WriteInt(buffer, kvp.Value.AsInt64());
		}
	}

	private static void WriteGroupFloat(StreamPeerBuffer buffer, Dictionary<StringName, Variant> group)
	{
		WriteVarint(buffer, group.Count);
		foreach (KeyValuePair<StringName, Variant> kvp in group)
		{
			WriteString(buffer, kvp.Key.ToString());
			WriteFloat(buffer, kvp.Value.AsDouble());
		}
	}

	private static void WriteGroupString(StreamPeerBuffer buffer, Dictionary<StringName, Variant> group)
	{
		WriteVarint(buffer, group.Count);
		foreach (KeyValuePair<StringName, Variant> kvp in group)
		{
			WriteString(buffer, kvp.Key.ToString());
			WriteString(buffer, kvp.Value.AsString());
		}
	}

	private static void WriteGroupBool(StreamPeerBuffer buffer, Dictionary<StringName, Variant> group)
	{
		WriteVarint(buffer, group.Count);
		foreach (KeyValuePair<StringName, Variant> kvp in group)
		{
			WriteString(buffer, kvp.Key.ToString());
			WriteBool(buffer, kvp.Value.AsBool());
		}
	}

	private static void WriteGroupOther(StreamPeerBuffer buffer, Dictionary<StringName, Variant> group)
	{
		foreach (KeyValuePair<StringName, Variant> kvp in group)
		{
			WriteString(buffer, kvp.Key.ToString());
			WriteGeneric(buffer, kvp.Value);
		}
	}

	private static int ReadGroupInt(StreamPeerBuffer buffer, Dictionary<StringName, Variant> dict)
	{
		int count = (int)ReadVarint(buffer);
		for (int i = 0; i < count; i++)
		{
			string keyStr = ReadString(buffer);
			StringName key = new StringName(keyStr);
			long val = ReadInt(buffer);
			dict[key] = val;
		}
		return count;
	}

	private static int ReadGroupFloat(StreamPeerBuffer buffer, Dictionary<StringName, Variant> dict)
	{
		int count = (int)ReadVarint(buffer);
		for (int i = 0; i < count; i++)
		{
			string keyStr = ReadString(buffer);
			StringName key = new StringName(keyStr);
			double val = ReadFloat(buffer);
			dict[key] = val;
		}
		return count;
	}

	private static int ReadGroupString(StreamPeerBuffer buffer, Dictionary<StringName, Variant> dict)
	{
		int count = (int)ReadVarint(buffer);
		for (int i = 0; i < count; i++)
		{
			string keyStr = ReadString(buffer);
			StringName key = new StringName(keyStr);
			string val = ReadString(buffer);
			dict[key] = val;
		}
		return count;
	}

	private static int ReadGroupBool(StreamPeerBuffer buffer, Dictionary<StringName, Variant> dict)
	{
		int count = (int)ReadVarint(buffer);
		for (int i = 0; i < count; i++)
		{
			string keyStr = ReadString(buffer);
			StringName key = new StringName(keyStr);
			bool val = ReadBool(buffer);
			dict[key] = val;
		}
		return count;
	}

	private static void ReadGroupOther(StreamPeerBuffer buffer, Dictionary<StringName, Variant> dict, int count)
	{
		for (int i = 0; i < count; i++)
		{
			string keyStr = ReadString(buffer);
			StringName key = new StringName(keyStr);
			Variant val = ReadGeneric(buffer);
			dict[key] = val;
		}
	}
}
