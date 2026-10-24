export const CATEGORY_IDS = ['kindness', 'environment', 'gratitude', 'courage', 'cooperation', 'honesty', 'self_care'] as const;
export type CategoryId = typeof CATEGORY_IDS[number];
export const CATEGORIES = [
  { id: 'kindness', name: '思いやり' }, { id: 'environment', name: '環境保護' },
  { id: 'gratitude', name: '感謝' }, { id: 'courage', name: '勇気' },
  { id: 'cooperation', name: '協力' }, { id: 'honesty', name: '誠実' },
  { id: 'self_care', name: 'セルフケア' },
] as const;
