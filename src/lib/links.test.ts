import { describe, expect, it } from "vitest";

import { sunnahItemHref, sunnahItemParams } from "./links";

describe("sunnah item links", () => {
  it("carry the fingerprint and the state hint", () => {
    expect(sunnahItemParams({ id: "س-01606", fp: "abc123", stateId: 42 })).toEqual({ id: "س-01606", fp: "abc123", st: "42" });
    expect(sunnahItemParams({ id: "ق-1", fp: null, stateId: 0 })).toEqual({ id: "ق-1" });
    expect(sunnahItemHref({ id: "1", fp: "f" })).toEqual({ pathname: "/s/item/[id]", params: { id: "1", fp: "f" } });
  });
});
