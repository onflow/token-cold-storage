import { getAccountAddress } from "flow-js-testing";

const UFIX64_PRECISION = 8;

// UFix64 values shall be always passed as strings
export const toUFix64 = (value) => value.toFixed(UFIX64_PRECISION);

export const getAccountA = async () => getAccountAddress("AccountA");
export const getAccountB = async () => getAccountAddress("AccountB");
