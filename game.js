const canvas = document.getElementById("game");
const ctx = canvas.getContext("2d");

const ui = {
  score: document.getElementById("score"),
  best: document.getElementById("best"),
  panel: document.getElementById("panel"),
  panelTitle: document.getElementById("panel-title"),
  panelText: document.getElementById("panel-text"),
  start: document.getElementById("start"),
  pause: document.getElementById("pause"),
  jump: document.getElementById("jump"),
};

const face = new Image();
face.src = "assets/shrestha-face.jpeg";

const audio = {
  music: new Audio("assets/bihari-phonk.mp3"),
  crash: new Audio("assets/crash-sound.mp4"),
  crashStart: 0,
  crashEnd: 1.15,
};

audio.music.loop = true;
audio.music.volume = 0.42;
audio.crash.volume = 1;
audio.crash.preload = "auto";

const state = {
  phase: "ready",
  score: 0,
  best: Number(localStorage.getItem("flappy-shrestha-best") || 0),
  lastTime: performance.now(),
  spawnTimer: 0,
  groundOffset: 0,
  pipes: [],
  clouds: [],
  particles: [],
};

const player = {
  x: 210,
  y: 280,
  vy: 0,
  radius: 34,
  rotation: 0,
};

const config = {
  gravity: 1180,
  flap: -420,
  pipeWidth: 94,
  pipeGap: 224,
  pipeSpeed: 205,
  pipeEvery: 1.55,
  groundHeight: 86,
};

const clamp = (n, min, max) => Math.max(min, Math.min(max, n));
const rand = (min, max) => min + Math.random() * (max - min);

function resize() {
  const rect = canvas.getBoundingClientRect();
  const dpr = window.devicePixelRatio || 1;
  canvas.width = Math.floor(rect.width * dpr);
  canvas.height = Math.floor(rect.height * dpr);
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
}

function reset() {
  const h = canvas.clientHeight || 640;
  state.phase = "playing";
  state.score = 0;
  state.spawnTimer = 0;
  state.groundOffset = 0;
  state.pipes = [];
  state.particles = [];
  player.x = Math.min(210, canvas.clientWidth * 0.32);
  player.y = h * 0.42;
  player.vy = 0;
  player.rotation = 0;
  ui.panel.classList.add("hidden");
  startMusic();
  stopCrash();
  spawnPipe(true);
  spawnPipe(false, canvas.clientWidth * 0.48);
}

function pauseGame() {
  if (state.phase !== "playing") return;
  state.phase = "paused";
  stopMusic();
  showPanel("Paused", "Take a breath. Press Resume to continue flying.", "Resume");
  ui.pause.textContent = ">";
  ui.pause.setAttribute("aria-label", "Resume game");
}

function resumeGame() {
  if (state.phase !== "paused") return;
  state.phase = "playing";
  ui.panel.classList.add("hidden");
  ui.pause.textContent = "II";
  ui.pause.setAttribute("aria-label", "Pause game");
  audio.music.play().catch(() => {});
}

function togglePause() {
  if (state.phase === "playing") {
    pauseGame();
    return;
  }
  if (state.phase === "paused") resumeGame();
}

function showPanel(title, text, button) {
  ui.panelTitle.textContent = title;
  ui.panelText.textContent = text;
  ui.start.textContent = button;
  ui.panel.classList.remove("hidden");
}

function flap() {
  if (state.phase === "paused") {
    resumeGame();
    return;
  }
  if (state.phase !== "playing") {
    reset();
    return;
  }
  player.vy = config.flap;
  for (let i = 0; i < 8; i++) {
    state.particles.push({
      x: player.x - 22,
      y: player.y + rand(-12, 18),
      vx: rand(-150, -50),
      vy: rand(-40, 70),
      life: rand(0.25, 0.55),
    });
  }
}

function startMusic() {
  try {
    audio.music.currentTime = 0;
  } catch {}
  audio.music.play().catch(() => {});
}

function stopMusic() {
  audio.music.pause();
}

function stopCrash() {
  audio.crash.pause();
  try {
    audio.crash.currentTime = audio.crashStart;
  } catch {}
}

function playCrash() {
  stopMusic();
  audio.crash.pause();
  try {
    audio.crash.currentTime = audio.crashStart;
  } catch {}
  audio.crash.volume = 1;
  audio.crash.play().catch(() => {});
}

function spawnPipe(first = false, extraX = 0) {
  const w = canvas.clientWidth || 900;
  const h = canvas.clientHeight || 640;
  const topLimit = 120;
  const bottomLimit = h - config.groundHeight - 92;
  const gapY = rand(topLimit + config.pipeGap / 2, bottomLimit - config.pipeGap / 2);
  state.pipes.push({
    x: w + extraX + (first ? 80 : 0),
    gapY,
    passed: false,
  });
}

function createClouds() {
  state.clouds = Array.from({ length: 8 }, () => ({
    x: rand(0, 980),
    y: rand(86, 310),
    s: rand(0.75, 1.55),
    speed: rand(10, 24),
  }));
}

function gameOver() {
  if (state.phase === "over") return;
  state.phase = "over";
  state.best = Math.max(state.best, state.score);
  localStorage.setItem("flappy-shrestha-best", String(state.best));
  playCrash();
  showPanel("Game Over", `Score: ${state.score}. Best: ${state.best}. Press space, click, or tap to try again.`, "Restart");
  ui.pause.textContent = "II";
  ui.pause.setAttribute("aria-label", "Pause game");
}

function update(dt) {
  const w = canvas.clientWidth || 900;
  const h = canvas.clientHeight || 640;
  const floor = h - config.groundHeight;

  state.clouds.forEach((cloud) => {
    cloud.x -= cloud.speed * dt;
    if (cloud.x < -150) {
      cloud.x = w + rand(40, 180);
      cloud.y = rand(86, 310);
    }
  });

  if (state.phase !== "playing") return;

  player.vy += config.gravity * dt;
  player.y += player.vy * dt;
  player.rotation = clamp(player.vy / 720, -0.55, 1.05);

  state.spawnTimer += dt;
  if (state.spawnTimer >= config.pipeEvery) {
    state.spawnTimer = 0;
    spawnPipe();
  }

  state.groundOffset = (state.groundOffset + config.pipeSpeed * dt) % 64;
  state.pipes.forEach((pipe) => {
    pipe.x -= config.pipeSpeed * dt;
    if (!pipe.passed && pipe.x + config.pipeWidth < player.x - player.radius) {
      pipe.passed = true;
      state.score += 1;
    }
  });
  state.pipes = state.pipes.filter((pipe) => pipe.x > -config.pipeWidth - 12);

  state.particles.forEach((p) => {
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    p.life -= dt;
  });
  state.particles = state.particles.filter((p) => p.life > 0);

  const hitFloor = player.y + player.radius > floor;
  const hitCeiling = player.y - player.radius < 0;
  const hitPipe = state.pipes.some((pipe) => {
    const withinX = player.x + player.radius * 0.74 > pipe.x && player.x - player.radius * 0.74 < pipe.x + config.pipeWidth;
    const outsideGap =
      player.y - player.radius * 0.74 < pipe.gapY - config.pipeGap / 2 ||
      player.y + player.radius * 0.74 > pipe.gapY + config.pipeGap / 2;
    return withinX && outsideGap;
  });

  if (hitFloor || hitCeiling || hitPipe) gameOver();
}

function drawSky(w, h) {
  const sky = ctx.createLinearGradient(0, 0, 0, h);
  sky.addColorStop(0, "#72cfff");
  sky.addColorStop(0.56, "#c7f4ff");
  sky.addColorStop(0.57, "#80d16d");
  sky.addColorStop(1, "#3d914c");
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, w, h);

  ctx.fillStyle = "rgba(255, 255, 255, 0.9)";
  state.clouds.forEach((cloud) => {
    ctx.save();
    ctx.translate(cloud.x, cloud.y);
    ctx.scale(cloud.s, cloud.s);
    ctx.beginPath();
    ctx.arc(0, 16, 24, 0, Math.PI * 2);
    ctx.arc(30, 6, 34, 0, Math.PI * 2);
    ctx.arc(70, 18, 28, 0, Math.PI * 2);
    ctx.rect(0, 18, 84, 30);
    ctx.fill();
    ctx.restore();
  });

  ctx.fillStyle = "rgba(42, 115, 77, 0.55)";
  for (let x = -80; x < w + 120; x += 160) {
    ctx.beginPath();
    ctx.moveTo(x, h - config.groundHeight);
    ctx.lineTo(x + 82, h - 220);
    ctx.lineTo(x + 170, h - config.groundHeight);
    ctx.fill();
  }
}

function drawPipe(pipe, h) {
  const topBottom = pipe.gapY - config.pipeGap / 2;
  const bottomTop = pipe.gapY + config.pipeGap / 2;
  const floor = h - config.groundHeight;

  ctx.fillStyle = "#258447";
  ctx.strokeStyle = "#13572d";
  ctx.lineWidth = 5;

  ctx.fillRect(pipe.x, -10, config.pipeWidth, topBottom + 10);
  ctx.strokeRect(pipe.x, -10, config.pipeWidth, topBottom + 10);
  ctx.fillRect(pipe.x - 10, topBottom - 28, config.pipeWidth + 20, 30);
  ctx.strokeRect(pipe.x - 10, topBottom - 28, config.pipeWidth + 20, 30);

  ctx.fillRect(pipe.x, bottomTop, config.pipeWidth, floor - bottomTop);
  ctx.strokeRect(pipe.x, bottomTop, config.pipeWidth, floor - bottomTop);
  ctx.fillRect(pipe.x - 10, bottomTop, config.pipeWidth + 20, 30);
  ctx.strokeRect(pipe.x - 10, bottomTop, config.pipeWidth + 20, 30);

  ctx.fillStyle = "rgba(255, 255, 255, 0.18)";
  ctx.fillRect(pipe.x + 14, 0, 12, topBottom - 36);
  ctx.fillRect(pipe.x + 14, bottomTop + 34, 12, floor - bottomTop - 38);
}

function drawGround(w, h) {
  const y = h - config.groundHeight;
  ctx.fillStyle = "#6fc35f";
  ctx.fillRect(0, y, w, config.groundHeight);
  ctx.fillStyle = "#d7a64b";
  ctx.fillRect(0, y + 22, w, config.groundHeight - 22);

  for (let x = -64 - state.groundOffset; x < w + 70; x += 64) {
    ctx.fillStyle = "#438d42";
    ctx.fillRect(x, y + 8, 42, 12);
    ctx.fillStyle = "rgba(112, 64, 32, 0.23)";
    ctx.fillRect(x + 18, y + 40, 34, 10);
  }
}

function drawPlayer() {
  ctx.save();
  ctx.translate(player.x, player.y);
  ctx.rotate(player.rotation);
  const bodyRadius = player.radius + 6;
  const faceRadius = player.radius - 4;

  ctx.fillStyle = "rgba(23, 48, 29, 0.26)";
  ctx.beginPath();
  ctx.ellipse(6, 39, 32, 10, 0, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = "#ffdd56";
  ctx.beginPath();
  ctx.moveTo(-28, 4);
  ctx.quadraticCurveTo(-65, 4, -54, -30);
  ctx.quadraticCurveTo(-30, -20, -18, -8);
  ctx.closePath();
  ctx.fill();

  ctx.fillStyle = "#ffdd56";
  ctx.beginPath();
  ctx.ellipse(0, 0, bodyRadius, bodyRadius * 0.94, 0, 0, Math.PI * 2);
  ctx.fill();

  ctx.save();
  ctx.beginPath();
  ctx.arc(0, 0, faceRadius, 0, Math.PI * 2);
  ctx.clip();
  if (face.complete && face.naturalWidth) {
    ctx.drawImage(face, 205, 480, 335, 355, -faceRadius, -faceRadius, faceRadius * 2, faceRadius * 2);
  } else {
    ctx.fillStyle = "#f0c092";
    ctx.fillRect(-faceRadius, -faceRadius, faceRadius * 2, faceRadius * 2);
  }
  ctx.restore();

  ctx.fillStyle = "#f26b4f";
  ctx.beginPath();
  ctx.moveTo(bodyRadius - 2, -3);
  ctx.lineTo(bodyRadius + 24, 7);
  ctx.lineTo(bodyRadius - 2, 18);
  ctx.closePath();
  ctx.fill();

  ctx.restore();
}

function drawParticles() {
  state.particles.forEach((p) => {
    ctx.globalAlpha = clamp(p.life * 2.4, 0, 1);
    ctx.fillStyle = "#fff2a7";
    ctx.beginPath();
    ctx.arc(p.x, p.y, 5, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalAlpha = 1;
  });
}

function render() {
  const w = canvas.clientWidth || 900;
  const h = canvas.clientHeight || 640;
  ctx.clearRect(0, 0, w, h);
  drawSky(w, h);
  drawParticles();
  state.pipes.forEach((pipe) => drawPipe(pipe, h));
  drawGround(w, h);
  drawPlayer();

  ui.score.textContent = String(state.score);
  ui.best.textContent = String(Math.max(state.best, state.score));
}

function loop(now) {
  const dt = Math.min(0.033, (now - state.lastTime) / 1000);
  state.lastTime = now;
  update(dt);
  render();
  requestAnimationFrame(loop);
}

window.addEventListener("resize", resize);
window.addEventListener("keydown", (event) => {
  if ([" ", "ArrowUp", "KeyW"].includes(event.code)) {
    event.preventDefault();
    flap();
  }
  if (event.code === "KeyP" || event.code === "Escape") {
    event.preventDefault();
    togglePause();
  }
});
canvas.addEventListener("pointerdown", (event) => {
  event.preventDefault();
  flap();
});
ui.start.addEventListener("click", flap);
ui.pause.addEventListener("click", togglePause);
ui.jump.addEventListener("pointerdown", (event) => {
  event.preventDefault();
  flap();
});
audio.crash.addEventListener("timeupdate", () => {
  if (audio.crash.currentTime >= audio.crashEnd) {
    audio.crash.pause();
    try {
      audio.crash.currentTime = audio.crashStart;
    } catch {}
  }
});

resize();
createClouds();
ui.best.textContent = String(state.best);
requestAnimationFrame(loop);
