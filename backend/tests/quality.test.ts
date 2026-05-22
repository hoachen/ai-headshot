import { describe, it, expect } from 'vitest';
import { stepToPercent, GENERATION_STEPS } from '../src/queue/job.types.js';

describe('QualityChecker thresholds', () => {
  const BRIGHTNESS_MIN = 80;
  const SHARPNESS_MIN = 100;
  const YAW_MAX = 0.44;
  const PITCH_MAX = 0.35;
  const CONFIDENCE_MIN = 0.7;
  const FACE_AREA_MIN = 0.20;

  it('passes brightness at 80', () => {
    expect(100 >= BRIGHTNESS_MIN).toBe(true);
    expect(79 >= BRIGHTNESS_MIN).toBe(false);
  });

  it('passes sharpness at 100', () => {
    expect(150 >= SHARPNESS_MIN).toBe(true);
    expect(99 >= SHARPNESS_MIN).toBe(false);
  });

  it('passes yaw within ±0.44 rad', () => {
    expect(Math.abs(0.3) <= YAW_MAX).toBe(true);
    expect(Math.abs(0.5) <= YAW_MAX).toBe(false);
  });

  it('passes pitch within ±0.35 rad', () => {
    expect(Math.abs(0.2) <= PITCH_MAX).toBe(true);
    expect(Math.abs(0.4) <= PITCH_MAX).toBe(false);
  });

  it('requires face confidence > 0.7', () => {
    expect(0.8 >= CONFIDENCE_MIN).toBe(true);
    expect(0.6 >= CONFIDENCE_MIN).toBe(false);
  });

  it('requires face area > 20% of frame', () => {
    expect(0.25 >= FACE_AREA_MIN).toBe(true);
    expect(0.15 >= FACE_AREA_MIN).toBe(false);
  });
});

describe('Generation step percentages', () => {
  it('all steps have a defined percentage', () => {
    for (const step of GENERATION_STEPS) {
      const pct = stepToPercent(step);
      expect(pct).toBeGreaterThan(0);
      expect(pct).toBeLessThanOrEqual(100);
    }
  });

  it('percentages are monotonically increasing', () => {
    const pcts = GENERATION_STEPS.map(s => stepToPercent(s));
    for (let i = 1; i < pcts.length; i++) {
      expect(pcts[i]).toBeGreaterThan(pcts[i - 1]);
    }
  });
});
