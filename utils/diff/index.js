const diff          = require('./diff.js');
const addedDiff     = require('./added.js');
const deletedDiff   = require('./deleted.js');
const updatedDiff   = require('./updated.js');
const detailedDiff  = require('./detailed.js');

module.exports = {
  addedDiff,
  diff,
  deletedDiff,
  updatedDiff,
  detailedDiff
};
