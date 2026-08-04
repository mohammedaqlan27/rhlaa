const { expect } = require('chai');
const admin = require('firebase-admin');
const test = require('firebase-functions-test')({
  databaseURL: 'http://localhost:9000',
  projectId: 'demo-project',
}, 'path/to/serviceAccountKey.json');

const myFunctions = require('../index.js');

describe('Agency transactions functions', () => {
  after(() => {
    test.cleanup();
  });

  it('should reject unauthenticated creditAgency', async () => {
    try {
      await myFunctions.creditAgency({}, { auth: null });
      throw new Error('Expected error');
    } catch (err) {
      expect(err.code).to.equal('unauthenticated');
    }
  });

  // المزيد من الاختبارات: successful credit, debit insufficient balance, createAgency duplicate mobile
});
