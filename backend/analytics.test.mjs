import {test} from 'node:test';
import assert from 'node:assert/strict';
import {privateAnalytics} from './analytics.mjs';

const range={userId:'eya',from:'2026-03-22T23:00:00Z',to:'2026-03-29T22:00:00Z',timezone:'Europe/Paris'};
test('verified metrics filter owner, current access, exclusive end and duplicates',async()=>{
  const record={id:'1',owner_id:'eya',accessible:true,completed_at:range.from};
  const source=async query=>{
    assert.equal(query.userId,'eya');
    return{tasks:[record,record,{...record,id:'other',owner_id:'someone-else'},{...record,id:'revoked',accessible:false},{...record,id:'end',completed_at:range.to},{...record,id:'old',completed_at:'2026-03-22T22:59:59Z'}],goals:[]};
  };
  const result=await privateAnalytics({...range,source});
  assert.equal(result.status,'available');assert.equal(result.tasks_completed,1);assert.equal(result.goals_completed,0);
});
test('missing sources stay null; zero is used only for a connected empty source',async()=>{
  const missing=await privateAnalytics({...range,source:null});assert.equal(missing.status,'unavailable');assert.equal(missing.tasks_completed,null);
  const partial=await privateAnalytics({...range,source:async()=>({tasks:[],goals:null})});assert.equal(partial.status,'partial');assert.equal(partial.tasks_completed,0);assert.equal(partial.goals_completed,null);
});
