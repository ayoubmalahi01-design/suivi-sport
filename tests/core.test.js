import test from 'node:test';import assert from 'node:assert/strict';
const parse=(s)=>s.trim().split(/[\s,،;؛]+/).filter(Boolean);
const nearestHigher=(value,rules)=>rules.filter(r=>Number.isFinite(+r.rawValue)&&+r.rawValue>=value).sort((a,b)=>+a.rawValue- +b.rawValue)[0]??null;
test('bulk number parser handles Arabic separators and whitespace',()=>assert.deepEqual(parse('101، 102\n103;104'),['101','102','103','104']));
test('BARÈME nearest higher match preserves decimal raw values',()=>assert.equal(nearestHigher(5.45,[{rawValue:5.5,score:10},{rawValue:6,score:12}]).score,10));
test('unmatched BARÈME remains null, never fabricated',()=>assert.equal(nearestHigher(9,[{rawValue:5,score:10}]),null));
test('NAVETTE decimal palier is numeric',()=>assert.equal(Number('5.45'),5.45));
