extends RefCounted
class_name MathUtils

static func generate_sine_table(table_size: int) -> Array:
	var sine_table = []
	sine_table.resize(table_size)
	var quarter = table_size / 4
	for i in range(0, quarter + 1):
		sine_table[i] = sin(TAU * i / table_size)
	for i in range(1, quarter):
		sine_table[quarter + i] = sine_table[quarter - i]
	for i in range(0, 2 * quarter):
		sine_table[2 * quarter + i] = -sine_table[i]
	return sine_table
