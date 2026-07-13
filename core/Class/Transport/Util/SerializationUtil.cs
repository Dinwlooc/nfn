using Godot;
using System;

/// <summary>
/// 序列化工具、。
/// 仅供 GDScript 调用，提供两对 snake_case 接口：
///   - write / read      ：自定义优化（不带类型标记），read 需显式传入类型
///   - write_generic / read_generic ：自描述（带类型标记），自动处理类型
/// 内部全部转发给 <see cref="CoreSerializationUtil"/>。
///
/// 注意：本工具不对 Vector2、Vector3、Quaternion 等几何类型做特殊兼容，
/// 直接使用引擎原生序列化（put_var/get_var）或自行扩展。
/// </summary>
[GlobalClass]
public partial class SerializationUtil : GodotObject
{
	/// <summary>
	/// 自定义优化写入（不带类型标记），从 Variant 中自动识别类型。
	/// </summary>
	public static void write(StreamPeerBuffer buffer, Variant value) =>
		CoreSerializationUtil.WriteVariantValue(buffer, value);

	/// <summary>
	/// 自定义优化读取（需显式传入类型标记）。
	/// </summary>
	/// <param name="type">Variant.Type 的整数值</param>
	public static Variant read(StreamPeerBuffer buffer, int type) =>
		CoreSerializationUtil.ReadVariantValue(buffer, type);

	/// <summary>
	/// 自描述写入（写入类型标记 + 值）。
	/// </summary>
	public static void write_generic(StreamPeerBuffer buffer, Variant value) =>
		CoreSerializationUtil.WriteGeneric(buffer, value);

	/// <summary>
	/// 自描述读取（先读类型标记，再读值）。
	/// </summary>
	public static Variant read_generic(StreamPeerBuffer buffer) =>
		CoreSerializationUtil.ReadGeneric(buffer);
}
