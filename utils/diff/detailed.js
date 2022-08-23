const addedDiff   = require('./added.js');
const deletedDiff = require('./deleted.js');
const updatedDiff = require('./updated.js');

const detailedDiff = (lhs, rhs) => ({
  added: addedDiff(lhs, rhs),
  deleted: deletedDiff(lhs, rhs),
  updated: updatedDiff(lhs, rhs),
});

module.exports = detailedDiff;
