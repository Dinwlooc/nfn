using Godot;
using System;

/// <summary>
/// 序列化工具的门面类，所有方法转发至 CoreSerializationUtil。
/// 仅供 GDScript 调用，提供两对 snake_case 接口：
///   - write / read      ：自定义优化（不带类型标记），read 需显式传入类型
///   - write_generic / read_generic ：自描述（带类型标记），自动处理类型
/// 注意：本工具不对 Vector2、Vector3、Quaternion 等几何类型做特殊兼容，
/// 直接使用引擎原生序列化（put_var/get_var）或自行扩展。
/// @facade
/// </summary>
[GlobalClass]
public partial class SerializationUtil : GodotObject
{
	/// <summary>
	/// 自定义优化写入（不带类型标记），从 Variant 中自动识别类型。
	/// @side-effect
	/// </summary>
	/// <param name="buffer">目标缓冲区。</param>
	/// <param name="value">待写入的值。</param>
	public static void write(StreamPeerBuffer buffer, Variant value) =>
		CoreSerializationUtil.WriteVariantValue(buffer, value);

	/// <summary>
	/// 自定义优化读取（需显式传入类型标记）。
	/// @side-effect
	/// </summary>
	/// <param name="buffer">源缓冲区。</param>
	/// <param name="type">Variant.Type 的整数值，指定期望读取的类型。</param>
	/// <returns>读取到的 Variant 值。</returns>
	public static Variant read(StreamPeerBuffer buffer, int type) =>
		CoreSerializationUtil.ReadVariantValue(buffer, type);

	/// <summary>
	/// 自描述写入（写入类型标记 + 值）。
	/// @side-effect
	/// </summary>
	/// <param name="buffer">目标缓冲区。</param>
	/// <param name="value">待写入的值。</param>
	public static void write_generic(StreamPeerBuffer buffer, Variant value) =>
		CoreSerializationUtil.WriteGeneric(buffer, value);

	/// <summary>
	/// 自描述读取（先读类型标记，再读值）。
	/// @side-effect
	/// </summary>
	/// <param name="buffer">源缓冲区。</param>
	/// <returns>读取到的 Variant 值（自动恢复类型）。</returns>
	public static Variant read_generic(StreamPeerBuffer buffer) =>
		CoreSerializationUtil.ReadGeneric(buffer);
}
