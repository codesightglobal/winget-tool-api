export function getSixDigitNoZero() {
  let num = "";
  while (num.length < 6) {
    let digit = Math.floor(Math.random() * 9) + 1; // 1 to 9
    num += digit;
  }
  return parseInt(num, 10);
}
