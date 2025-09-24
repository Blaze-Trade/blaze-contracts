export function clampNumber(num: number | undefined, min: number = 0, max: number = 100_000_000): string {
  // Handle undefined or null values
  if (num === undefined || num === null || isNaN(num)) {
    return "0";
  }

  if (num < min) {
    return `<${min.toString()}`;
  }

  if (num > max) {
    return `>${max.toString()}`;
  }

  return num.toString();
}
