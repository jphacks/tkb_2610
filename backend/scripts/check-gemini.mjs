import 'dotenv/config';
import { DEFAULT_GEMINI_MODEL, judgeDeedWithGemini } from '../dist/lib/gemini.js';
const result = await judgeDeedWithGemini('公園に落ちていたごみを拾い、分別してごみ箱に捨てた。', '動作確認');
if (!result.valid) throw new Error('The known good deed was not accepted');
console.log(JSON.stringify({ provider: 'Gemini', model: process.env.GEMINI_MODEL || DEFAULT_GEMINI_MODEL, ...result }, null, 2));
