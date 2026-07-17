import assert from "node:assert/strict";
import test from "node:test";

import { sanitizeMaintenancePlan } from "../api/complete.ts";

test("maintenance plan keeps grounded fields and clamps unsafe values", () => {
  const result = sanitizeMaintenancePlan({
    suggestions: [{
      title: "  Fren sistemi kontrolü  ",
      message: "Aktif hatırlatıcı mevcut.",
      severity: "important",
      suggestedIntervalKm: 2_000,
      suggestedIntervalMonths: 1,
      evidence: ["Fren kontrolü 96.000 km'de yaklaşan olarak kayıtlı", "x".repeat(300)],
      confidence: "high",
      recommendedAction: "Servisten kontrol randevusu al.",
      limitation: null,
    }],
  });

  assert.equal(result?.length, 1);
  assert.equal(result?.[0].title, "Fren sistemi kontrolü");
  assert.equal(result?.[0].severity, "important");
  assert.equal(result?.[0].confidence, "high");
  assert.equal(result?.[0].suggestedIntervalKm, 2_000);
  assert.equal(result?.[0].evidence[1].length, 180);
});

test("maintenance plan rejects an unusable non-empty model response", () => {
  assert.equal(sanitizeMaintenancePlan({ suggestions: [{ title: 42 }] }), null);
});

test("maintenance plan removes duplicates and invalid reminder intervals", () => {
  const result = sanitizeMaintenancePlan({
    suggestions: [
      {
        title: "Yağ kontrolü",
        message: "Kayıtları kontrol et.",
        severity: "unexpected",
        confidence: "unexpected",
        suggestedIntervalKm: 900_000,
        suggestedIntervalMonths: -2,
      },
      {
        title: "yağ kontrolü",
        message: "Aynı öneri.",
        severity: "info",
      },
    ],
  });

  assert.equal(result?.length, 1);
  assert.equal(result?.[0].severity, "info");
  assert.equal(result?.[0].confidence, "low");
  assert.equal(result?.[0].suggestedIntervalKm, null);
  assert.equal(result?.[0].suggestedIntervalMonths, null);
});
