const isDate         = d => d instanceof Date;
const isEmpty        = o => Object.keys(o).length === 0;
const isObject       = o => o != null && typeof o === 'object';
const hasOwnProperty = (o, ...args) => Object.prototype.hasOwnProperty.call(o, ...args)
const isEmptyObject  = (o) => isObject(o) && isEmpty(o);

exports.isDate         = isDate;
exports.isEmpty        = isEmpty;
exports.isObject       = isObject;
exports.hasOwnProperty = hasOwnProperty;
exports.isEmptyObject  = isEmptyObject;
