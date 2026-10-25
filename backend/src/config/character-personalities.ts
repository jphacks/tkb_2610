import { z } from 'zod';
import profiles from './character-personalities.json' with { type: 'json' };

const personalitySchema = z.object({
  name: z.string().min(1),
  personality: z.string().min(1),
  firstPerson: z.string().min(1),
  tone: z.string().min(1),
  demoTemplate: z.string().refine((text) => text.split('{action}').length === 2),
}).strict();

export const characterPersonalities = z.record(z.string(), personalitySchema).parse(profiles);

export function characterPersonality(imageId = 'base_01') {
  const resolved = imageId === 'turtle' || imageId === 'demo_turtle'
    ? 'stage1_honesty' : imageId;
  return Object.hasOwn(characterPersonalities, resolved)
    ? characterPersonalities[resolved] : characterPersonalities.base_01;
}
