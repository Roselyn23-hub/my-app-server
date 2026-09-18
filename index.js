const express = require('express');
const app = express();

app.get('/doc/:id', (req, res) => {
  res.send(`Document ID: ${req.params.id}`); // placeholder
});

app.listen(3000, () => console.log('Server running on port 3000'));