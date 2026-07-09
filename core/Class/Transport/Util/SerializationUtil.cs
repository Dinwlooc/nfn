using Godot;
using System;
using System.Text;
using System.Collections.Generic;

/// <summary>
/// 序列化工具类，提供高效的类型感知序列化/反序列化。
/// 完全兼容 GDScript 版本，所有方法签名保持一致。
/// </summary>
[GlobalClass]
public partial class SerializationUtil : GodotObject
{
	private const int VARINT_MASK = 0x7F;
	private const int VARINT_CONTINUE_FLAG = 0x80;

	// ========== 公共写入入口 ==========
	public static void write(StreamPeerBuffer buffer, Variant value)
	{
		switch (value.VariantType)
		{
			case Variant.Type.String:
				_write_string(buffer, value.AsString());
				break;
			case Variant.Type.Int:
				_write_varint(buffer, value.AsInt64());
				break;
			case Variant.Type.StringName:
				_write_string(buffer, value.AsStringName().ToString());
				break;
			case Variant.Type.Float:
				buffer.PutDouble(value.AsDouble());
				break;
			case Variant.Type.Bool:
				_write_bool(buffer, value.AsBool());
				break;
			case Variant.Type.PackedByteArray:
				_write_packed_byte_array(buffer, value.AsByteArray());
				break;
			case Variant.Type.PackedInt32Array:
				_write_packed_int_array(buffer, value.AsInt32Array());
				break;
			case Variant.Type.PackedInt64Array:
				_write_packed_int_array(buffer, value.AsInt64Array());
				break;
			case Variant.Type.Dictionary:
				Dictionary<StringName, Variant> innerDict = ConvertGodotDictToInner(value.AsGodotDictionary());
				_write_dictionary_inner(buffer, innerDict);
				break;
			case Variant.Type.Nil:
				throw new NotSupportedException($"注意到NIL类型: {value.VariantType}");
				break;
			default:
				throw new NotSupportedException($"试图序列化不支持的类型: {value.VariantType}");
		}
	}

	// ========== 公共读取入口 ==========
	public static Variant read(StreamPeerBuffer buffer, int type)
	{
		switch ((Variant.Type)type)
		{
			case Variant.Type.String:
				return _read_string(buffer);
			case Variant.Type.Int:
				return _read_varint(buffer);
			case Variant.Type.StringName:
				return new StringName(_read_string(buffer));
			case Variant.Type.Float:
				return buffer.GetDouble();
			case Variant.Type.Bool:
				return _read_bool(buffer);
			case Variant.Type.PackedByteArray:
				return _read_packed_byte_array(buffer);
			case Variant.Type.PackedInt32Array:
				return _read_packed_int32_array(buffer);
			case Variant.Type.PackedInt64Array:
				return _read_packed_int64_array(buffer);
			case Variant.Type.Dictionary:
				Dictionary<StringName, Variant> innerDict = _read_dictionary_inner(buffer);
				return ConvertInnerToGodotDict(innerDict);
			case Variant.Type.Nil:
				return new Variant();   // 显式构造 Nil Variant
			default:
				return buffer.GetVar();
		}
	}

	// ========== 泛型写入（自描述类型） ==========
	public static void generic_write(StreamPeerBuffer buffer, Variant value)
	{
		_write_varint(buffer, (int)value.VariantType);
		write(buffer, value);
	}

	public static Variant generic_read(StreamPeerBuffer buffer)
	{
		int type = (int)_read_varint(buffer);
		return read(buffer, type);
	}

	// ==================== 私有辅助方法 ====================
/// <summary>
/// 将 long 编码为 ZigZag 无符号值，再以 7-bit 变长格式写入
/// </summary>
private static void _write_varint(StreamPeerBuffer buffer, long value)
{
	unchecked
	{
		// ZigZag 编码：将符号位移到最低位
		ulong zigzag = (ulong)((value << 1) ^ (value >> 63));
		_write_varint_unsigned(buffer, zigzag);
	}
}

/// <summary>
/// 从缓冲区读取变长整数，解码为 long
/// </summary>
private static long _read_varint(StreamPeerBuffer buffer)
{
	ulong zigzag = _read_varint_unsigned(buffer);
	long decoded = (long)((zigzag >> 1) ^ (ulong)(-(long)(zigzag & 1)));
	return decoded;
}
/// <summary>
/// 写入无符号变长整数
/// </summary>
private static void _write_varint_unsigned(StreamPeerBuffer buffer, ulong value)
{
	while (value >= 0x80)
	{
		buffer.PutU8((byte)((value & 0x7F) | 0x80));
		value >>= 7;
	}
	buffer.PutU8((byte)value);
}
/// <summary>
/// 读取无符号变长整数
/// </summary>
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


	private static void _write_string(StreamPeerBuffer buffer, string value)
	{
		byte[] utf8 = Encoding.UTF8.GetBytes(value);
		_write_varint(buffer, utf8.Length);
		if (utf8.Length > 0)
			buffer.PutData(utf8);
	}

	private static string _read_string(StreamPeerBuffer buffer)
	{
		int len = (int)_read_varint(buffer);
		if (len == 0) return "";
		return buffer.GetUtf8String(len);
	}

	private static void _write_bool(StreamPeerBuffer buffer, bool value) =>
		buffer.PutU8((byte)(value ? 1 : 0));

	private static bool _read_bool(StreamPeerBuffer buffer) =>
		buffer.GetU8() != 0;

	private static void _write_packed_int_array(StreamPeerBuffer buffer, int[] array)
	{
		_write_varint(buffer, array.Length);
		foreach (int v in array)
			_write_varint(buffer, v);
	}

	private static void _write_packed_int_array(StreamPeerBuffer buffer, long[] array)
	{
		_write_varint(buffer, array.Length);
		foreach (long v in array)
			_write_varint(buffer, v);
	}

	private static int[] _read_packed_int32_array(StreamPeerBuffer buffer)
	{
		int size = (int)_read_varint(buffer);
		int[] arr = new int[size];
		for (int i = 0; i < size; i++)
			arr[i] = (int)_read_varint(buffer);
		return arr;
	}

	private static long[] _read_packed_int64_array(StreamPeerBuffer buffer)
	{
		int size = (int)_read_varint(buffer);
		long[] arr = new long[size];
		for (int i = 0; i < size; i++)
			arr[i] = _read_varint(buffer);
		return arr;
	}

	private static void _write_packed_byte_array(StreamPeerBuffer buffer, byte[] array)
	{
		_write_varint(buffer, array.Length);
		if (array.Length > 0)
			buffer.PutData(array);
	}

	private static byte[] _read_packed_byte_array(StreamPeerBuffer buffer)
	{
		int size = (int)_read_varint(buffer);
		if (size == 0) return Array.Empty<byte>();
		Godot.Collections.Array result = buffer.GetData(size);
		if (result.Count < 2) return Array.Empty<byte>();
		return result[1].AsByteArray();
	}

	// ==================== 字典转换与内部处理 ====================

	private static Dictionary<StringName, Variant> ConvertGodotDictToInner(Godot.Collections.Dictionary godotDict)
	{
		Dictionary<StringName, Variant> inner = new Dictionary<StringName, Variant>();
		foreach (Variant key in godotDict.Keys)
		{
			StringName stringKey = key.AsStringName();
			inner[stringKey] = godotDict[key];
		}
		return inner;
	}

	private static Godot.Collections.Dictionary ConvertInnerToGodotDict(Dictionary<StringName, Variant> inner)
	{
		Godot.Collections.Dictionary godotDict = new Godot.Collections.Dictionary();
		foreach (KeyValuePair<StringName, Variant> kvp in inner)
		{
			godotDict[(Variant)kvp.Key] = kvp.Value;
		}
		return godotDict;
	}

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

		Dictionary<StringName, Variant>[] groups = _classify_dict_entries(dict);
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

		Dictionary<StringName, Variant> dict = new Dictionary<StringName, Variant>();
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
			_write_string(buffer, kvp.Key.ToString());
			generic_write(buffer, kvp.Value);
		}
	}

	private static Dictionary<StringName, Variant> _read_small_dict_entries(StreamPeerBuffer buffer, int count)
	{
		Dictionary<StringName, Variant> dict = new Dictionary<StringName, Variant>();
		for (int i = 0; i < count; i++)
		{
			string keyStr = _read_string(buffer);
			StringName key = new StringName(keyStr);
			Variant val = generic_read(buffer);
			dict[key] = val;
		}
		return dict;
	}

	private static Dictionary<StringName, Variant>[] _classify_dict_entries(Dictionary<StringName, Variant> dict)
	{
		Dictionary<StringName, Variant>[] groups = new Dictionary<StringName, Variant>[5];
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
			_write_string(buffer, kvp.Key.ToString());
			_write_varint(buffer, kvp.Value.AsInt64());
		}
	}

	private static void _write_group_float(StreamPeerBuffer buffer, Dictionary<StringName, Variant> group)
	{
		_write_varint(buffer, group.Count);
		foreach (KeyValuePair<StringName, Variant> kvp in group)
		{
			_write_string(buffer, kvp.Key.ToString());
			buffer.PutDouble(kvp.Value.AsDouble());
		}
	}

	private static void _write_group_string(StreamPeerBuffer buffer, Dictionary<StringName, Variant> group)
	{
		_write_varint(buffer, group.Count);
		foreach (KeyValuePair<StringName, Variant> kvp in group)
		{
			_write_string(buffer, kvp.Key.ToString());
			_write_string(buffer, kvp.Value.AsString());
		}
	}

	private static void _write_group_bool(StreamPeerBuffer buffer, Dictionary<StringName, Variant> group)
	{
		_write_varint(buffer, group.Count);
		foreach (KeyValuePair<StringName, Variant> kvp in group)
		{
			_write_string(buffer, kvp.Key.ToString());
			_write_bool(buffer, kvp.Value.AsBool());
		}
	}

	private static void _write_group_other(StreamPeerBuffer buffer, Dictionary<StringName, Variant> group)
	{
		foreach (KeyValuePair<StringName, Variant> kvp in group)
		{
			_write_string(buffer, kvp.Key.ToString());
			generic_write(buffer, kvp.Value);
		}
	}

	private static int _read_group_int(StreamPeerBuffer buffer, Dictionary<StringName, Variant> dict)
	{
		int count = (int)_read_varint(buffer);
		for (int i = 0; i < count; i++)
		{
			string keyStr = _read_string(buffer);
			StringName key = new StringName(keyStr);
			long val = _read_varint(buffer);
			dict[key] = val;
		}
		return count;
	}

	private static int _read_group_float(StreamPeerBuffer buffer, Dictionary<StringName, Variant> dict)
	{
		int count = (int)_read_varint(buffer);
		for (int i = 0; i < count; i++)
		{
			string keyStr = _read_string(buffer);
			StringName key = new StringName(keyStr);
			double val = buffer.GetDouble();
			dict[key] = val;
		}
		return count;
	}

	private static int _read_group_string(StreamPeerBuffer buffer, Dictionary<StringName, Variant> dict)
	{
		int count = (int)_read_varint(buffer);
		for (int i = 0; i < count; i++)
		{
			string keyStr = _read_string(buffer);
			StringName key = new StringName(keyStr);
			string val = _read_string(buffer);
			dict[key] = val;
		}
		return count;
	}

	private static int _read_group_bool(StreamPeerBuffer buffer, Dictionary<StringName, Variant> dict)
	{
		int count = (int)_read_varint(buffer);
		for (int i = 0; i < count; i++)
		{
			string keyStr = _read_string(buffer);
			StringName key = new StringName(keyStr);
			bool val = _read_bool(buffer);
			dict[key] = val;
		}
		return count;
	}

	private static void _read_group_other(StreamPeerBuffer buffer, Dictionary<StringName, Variant> dict, int count)
	{
		for (int i = 0; i < count; i++)
		{
			string keyStr = _read_string(buffer);
			StringName key = new StringName(keyStr);
			Variant val = generic_read(buffer);
			dict[key] = val;
		}
	}
}
