using Godot;
using System;
using System.Text;
using System.Collections.Generic;

/// <summary>
/// 序列化工具类，提供高效的类型感知序列化/反序列化。
/// 分为两层：C# 原生层（直接操作 C# 类型，字典使用 Dictionary<StringName, Variant>）
/// 和 Godot 兼容层（操作 Variant，内部调用 C# 层）。
/// </summary>
[GlobalClass]
public partial class SerializationUtil : GodotObject
{
	private const int VARINT_MASK = 0x7F;
	private const int VARINT_CONTINUE_FLAG = 0x80;

	// ============================================================
	//  C# 原生层公共方法（所有方法直接操作 C# 类型）
	// ============================================================

	/// <summary>写入 long（变长编码）</summary>
	public static void write_int(StreamPeerBuffer buffer, long value) => _write_varint(buffer, value);

	/// <summary>读取 long</summary>
	public static long read_int(StreamPeerBuffer buffer) => _read_varint(buffer);

	/// <summary>写入 double（8字节）</summary>
	public static void write_float(StreamPeerBuffer buffer, double value) => buffer.PutDouble(value);

	/// <summary>读取 double</summary>
	public static double read_float(StreamPeerBuffer buffer) => buffer.GetDouble();

	/// <summary>写入 bool（1字节）</summary>
	public static void write_bool(StreamPeerBuffer buffer, bool value) => buffer.PutU8((byte)(value ? 1 : 0));

	/// <summary>读取 bool</summary>
	public static bool read_bool(StreamPeerBuffer buffer) => buffer.GetU8() != 0;

	/// <summary>写入 string（UTF-8，长度前缀）</summary>
	public static void write_string(StreamPeerBuffer buffer, string value)
	{
		byte[] utf8 = Encoding.UTF8.GetBytes(value);
		_write_varint(buffer, utf8.Length);
		if (utf8.Length > 0)
			buffer.PutData(utf8);
	}

	/// <summary>读取 string</summary>
	public static string read_string(StreamPeerBuffer buffer)
	{
		int len = (int)_read_varint(buffer);
		return len == 0 ? "" : buffer.GetUtf8String(len);
	}

	/// <summary>写入 StringName（存储为字符串）</summary>
	public static void write_stringname(StreamPeerBuffer buffer, StringName value) =>
		write_string(buffer, value.ToString());

	/// <summary>读取 StringName</summary>
	public static StringName read_stringname(StreamPeerBuffer buffer) =>
		new StringName(read_string(buffer));

	/// <summary>写入 byte[]（长度前缀）</summary>
	public static void write_byte_array(StreamPeerBuffer buffer, byte[] array)
	{
		_write_varint(buffer, array.Length);
		if (array.Length > 0)
			buffer.PutData(array);
	}

	/// <summary>读取 byte[]</summary>
	public static byte[] read_byte_array(StreamPeerBuffer buffer)
	{
		int size = (int)_read_varint(buffer);
		if (size == 0) return Array.Empty<byte>();
		Godot.Collections.Array result = buffer.GetData(size);
		if (result.Count < 2) return Array.Empty<byte>();
		return result[1].AsByteArray();
	}

	/// <summary>写入 int[]（每个元素变长编码）</summary>
	public static void write_int32_array(StreamPeerBuffer buffer, int[] array)
	{
		_write_varint(buffer, array.Length);
		foreach (int v in array)
			_write_varint(buffer, v);
	}

	/// <summary>读取 int[]</summary>
	public static int[] read_int32_array(StreamPeerBuffer buffer)
	{
		int size = (int)_read_varint(buffer);
		int[] arr = new int[size];
		for (int i = 0; i < size; i++)
			arr[i] = (int)_read_varint(buffer);
		return arr;
	}

	/// <summary>写入 long[]（每个元素变长编码）</summary>
	public static void write_int64_array(StreamPeerBuffer buffer, long[] array)
	{
		_write_varint(buffer, array.Length);
		foreach (long v in array)
			_write_varint(buffer, v);
	}

	/// <summary>读取 long[]</summary>
	public static long[] read_int64_array(StreamPeerBuffer buffer)
	{
		int size = (int)_read_varint(buffer);
		long[] arr = new long[size];
		for (int i = 0; i < size; i++)
			arr[i] = _read_varint(buffer);
		return arr;
	}

	// ---------- 字典（C# 原生类型：键 StringName，值 Variant） ----------
	/// <summary>写入字典，分组优化</summary>
	public static void write_dictionary(StreamPeerBuffer buffer, Dictionary<StringName, Variant> dict)
	{
		_write_dictionary_inner(buffer, dict);
	}

	/// <summary>读取字典</summary>
	public static Dictionary<StringName, Variant> read_dictionary(StreamPeerBuffer buffer) =>
		_read_dictionary_inner(buffer);

	// ---------- 泛型（自描述） ----------
	/// <summary>写入任意 Variant（先写类型标记，再写值）</summary>
	public static void write_generic(StreamPeerBuffer buffer, Variant value)
	{
		if (value.VariantType == Variant.Type.Nil)
			throw new NotSupportedException("Nil values are not supported.");
		_write_varint(buffer, (int)value.VariantType);
		write(buffer, value); // 直接调用 Godot 兼容层的 write，它会分派到对应的 C# 方法
	}

	/// <summary>读取任意 Variant（先读类型标记，再读值）</summary>
	public static Variant read_generic(StreamPeerBuffer buffer)
	{
		int typeId = (int)_read_varint(buffer);
		return read(buffer, typeId); // 调用 Godot 兼容层的 read
	}

	// ============================================================
	//  Godot 兼容层公共方法（操作 Variant）
	// ============================================================

	/// <summary>写入 Variant（自动识别类型）</summary>
	public static void write(StreamPeerBuffer buffer, Variant value)
	{
		switch (value.VariantType)
		{
			case Variant.Type.String:       write_string(buffer, value.AsString()); break;
			case Variant.Type.Int:          write_int(buffer, value.AsInt64()); break;
			case Variant.Type.StringName:   write_stringname(buffer, value.AsStringName()); break;
			case Variant.Type.Float:        write_float(buffer, value.AsDouble()); break;
			case Variant.Type.Bool:         write_bool(buffer, value.AsBool()); break;
			case Variant.Type.PackedByteArray: write_byte_array(buffer, value.AsByteArray()); break;
			case Variant.Type.PackedInt32Array: write_int32_array(buffer, value.AsInt32Array()); break;
			case Variant.Type.PackedInt64Array: write_int64_array(buffer, value.AsInt64Array()); break;
			case Variant.Type.Dictionary:
				var godotDict = value.AsGodotDictionary();
				var innerDict = GodotTypeConverter.ToInnerDictionary(godotDict);
				write_dictionary(buffer, innerDict);
				break;
			case Variant.Type.Nil:
				throw new NotSupportedException("Nil type cannot be serialized.");
			default:
				throw new NotSupportedException($"Unsupported Variant type: {value.VariantType}");
		}
	}

	/// <summary>读取并返回 Variant（根据类型标记）</summary>
	public static Variant read(StreamPeerBuffer buffer, int type)
	{
		switch ((Variant.Type)type)
		{
			case Variant.Type.String:       return read_string(buffer);
			case Variant.Type.Int:          return read_int(buffer);
			case Variant.Type.StringName:   return read_stringname(buffer);
			case Variant.Type.Float:        return read_float(buffer);
			case Variant.Type.Bool:         return read_bool(buffer);
			case Variant.Type.PackedByteArray: return read_byte_array(buffer);
			case Variant.Type.PackedInt32Array: return read_int32_array(buffer);
			case Variant.Type.PackedInt64Array: return read_int64_array(buffer);
			case Variant.Type.Dictionary:
				var innerDict = read_dictionary(buffer);
				return Variant.From(GodotTypeConverter.ToGodotDictionary(innerDict));
			case Variant.Type.Nil:
				throw new NotSupportedException("Nil type cannot be read.");
			default:
				return buffer.GetVar(); // fallback
		}
	}

	/// <summary>泛型写入（自描述）—— Godot 版本（内部委托给 write_generic）</summary>
	public static void generic_write(StreamPeerBuffer buffer, Variant value) =>
		write_generic(buffer, value);

	/// <summary>泛型读取（自描述）—— Godot 版本</summary>
	public static Variant generic_read(StreamPeerBuffer buffer) =>
		read_generic(buffer);

	// ============================================================
	//  私有辅助方法（底层基础能力）
	// ============================================================

	/// <summary>写入变长无符号整数（底层）</summary>
	private static void _write_varint_unsigned(StreamPeerBuffer buffer, ulong value)
	{
		while (value >= 0x80)
		{
			buffer.PutU8((byte)((value & 0x7F) | 0x80));
			value >>= 7;
		}
		buffer.PutU8((byte)value);
	}

	/// <summary>读取变长无符号整数（底层）</summary>
	private static ulong _read_varint_unsigned(StreamPeerBuffer buffer)
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

	/// <summary>写入 ZigZag 编码的有符号长整数</summary>
	private static void _write_varint(StreamPeerBuffer buffer, long value)
	{
		unchecked
		{
			ulong zigzag = (ulong)((value << 1) ^ (value >> 63));
			_write_varint_unsigned(buffer, zigzag);
		}
	}

	/// <summary>读取 ZigZag 解码的有符号长整数</summary>
	private static long _read_varint(StreamPeerBuffer buffer)
	{
		ulong zigzag = _read_varint_unsigned(buffer);
		long decoded = (long)((zigzag >> 1) ^ (ulong)(-(long)(zigzag & 1)));
		return decoded;
	}

	// ============================================================
	//  字典内部序列化核心（操作 Dictionary<StringName, Variant>）
	// ============================================================

	private static void _write_dictionary_inner(StreamPeerBuffer buffer, Dictionary<StringName, Variant> dict)
	{
		int total = dict.Count;
		_write_varint(buffer, total);
		if (total == 0) return;

		if (total <= 5)
		{
			_write_small_dict_entries(buffer, dict);
			return;
		}

		var groups = _classify_dict_entries(dict);
		_write_group_int(buffer, groups[0]);
		_write_group_float(buffer, groups[1]);
		_write_group_string(buffer, groups[2]);
		_write_group_bool(buffer, groups[3]);
		_write_group_other(buffer, groups[4]);
	}

	private static Dictionary<StringName, Variant> _read_dictionary_inner(StreamPeerBuffer buffer)
	{
		int total = (int)_read_varint(buffer);
		if (total == 0) return new Dictionary<StringName, Variant>();

		if (total <= 5)
			return _read_small_dict_entries(buffer, total);

		var dict = new Dictionary<StringName, Variant>();
		int processed = 0;
		processed += _read_group_int(buffer, dict);
		processed += _read_group_float(buffer, dict);
		processed += _read_group_string(buffer, dict);
		processed += _read_group_bool(buffer, dict);
		int otherCount = total - processed;
		if (otherCount > 0)
			_read_group_other(buffer, dict, otherCount);
		return dict;
	}

	private static void _write_small_dict_entries(StreamPeerBuffer buffer, Dictionary<StringName, Variant> dict)
	{
		foreach (KeyValuePair<StringName, Variant> kvp in dict)
		{
			write_string(buffer, kvp.Key.ToString());
			write_generic(buffer, kvp.Value);
		}
	}

	private static Dictionary<StringName, Variant> _read_small_dict_entries(StreamPeerBuffer buffer, int count)
	{
		var dict = new Dictionary<StringName, Variant>();
		for (int i = 0; i < count; i++)
		{
			string keyStr = read_string(buffer);
			StringName key = new StringName(keyStr);
			Variant val = read_generic(buffer);
			dict[key] = val;
		}
		return dict;
	}

	private static Dictionary<StringName, Variant>[] _classify_dict_entries(Dictionary<StringName, Variant> dict)
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

	private static void _write_group_int(StreamPeerBuffer buffer, Dictionary<StringName, Variant> group)
	{
		_write_varint(buffer, group.Count);
		foreach (KeyValuePair<StringName, Variant> kvp in group)
		{
			write_string(buffer, kvp.Key.ToString());
			write_int(buffer, kvp.Value.AsInt64());
		}
	}

	private static void _write_group_float(StreamPeerBuffer buffer, Dictionary<StringName, Variant> group)
	{
		_write_varint(buffer, group.Count);
		foreach (KeyValuePair<StringName, Variant> kvp in group)
		{
			write_string(buffer, kvp.Key.ToString());
			write_float(buffer, kvp.Value.AsDouble());
		}
	}

	private static void _write_group_string(StreamPeerBuffer buffer, Dictionary<StringName, Variant> group)
	{
		_write_varint(buffer, group.Count);
		foreach (KeyValuePair<StringName, Variant> kvp in group)
		{
			write_string(buffer, kvp.Key.ToString());
			write_string(buffer, kvp.Value.AsString());
		}
	}

	private static void _write_group_bool(StreamPeerBuffer buffer, Dictionary<StringName, Variant> group)
	{
		_write_varint(buffer, group.Count);
		foreach (KeyValuePair<StringName, Variant> kvp in group)
		{
			write_string(buffer, kvp.Key.ToString());
			write_bool(buffer, kvp.Value.AsBool());
		}
	}

	private static void _write_group_other(StreamPeerBuffer buffer, Dictionary<StringName, Variant> group)
	{
		foreach (KeyValuePair<StringName, Variant> kvp in group)
		{
			write_string(buffer, kvp.Key.ToString());
			write_generic(buffer, kvp.Value);
		}
	}

	private static int _read_group_int(StreamPeerBuffer buffer, Dictionary<StringName, Variant> dict)
	{
		int count = (int)_read_varint(buffer);
		for (int i = 0; i < count; i++)
		{
			string keyStr = read_string(buffer);
			StringName key = new StringName(keyStr);
			long val = read_int(buffer);
			dict[key] = val;
		}
		return count;
	}

	private static int _read_group_float(StreamPeerBuffer buffer, Dictionary<StringName, Variant> dict)
	{
		int count = (int)_read_varint(buffer);
		for (int i = 0; i < count; i++)
		{
			string keyStr = read_string(buffer);
			StringName key = new StringName(keyStr);
			double val = read_float(buffer);
			dict[key] = val;
		}
		return count;
	}

	private static int _read_group_string(StreamPeerBuffer buffer, Dictionary<StringName, Variant> dict)
	{
		int count = (int)_read_varint(buffer);
		for (int i = 0; i < count; i++)
		{
			string keyStr = read_string(buffer);
			StringName key = new StringName(keyStr);
			string val = read_string(buffer);
			dict[key] = val;
		}
		return count;
	}

	private static int _read_group_bool(StreamPeerBuffer buffer, Dictionary<StringName, Variant> dict)
	{
		int count = (int)_read_varint(buffer);
		for (int i = 0; i < count; i++)
		{
			string keyStr = read_string(buffer);
			StringName key = new StringName(keyStr);
			bool val = read_bool(buffer);
			dict[key] = val;
		}
		return count;
	}

	private static void _read_group_other(StreamPeerBuffer buffer, Dictionary<StringName, Variant> dict, int count)
	{
		for (int i = 0; i < count; i++)
		{
			string keyStr = read_string(buffer);
			StringName key = new StringName(keyStr);
			Variant val = read_generic(buffer);
			dict[key] = val;
		}
	}
}
