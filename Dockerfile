FROM node:20-slim

# ── System deps: gosu (privilege dropping) + Python (for Hermes Agent) ──
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
       gosu \
       python3 \
       python3-pip \
       python3-venv \
       git \
  && rm -rf /var/lib/apt/lists/*

# ── Install Hermes Agent CLI ──
RUN pip install hermes-agent --break-system-packages

# ── Create non-root user (Claude CLI refuses --dangerously-skip-permissions as root) ──
RUN groupadd -r paperclip && useradd -r -g paperclip -m -d /home/paperclip -s /bin/bash paperclip

# ── Create the paperclip home directory (Railway volume mount point) ──
RUN mkdir -p /paperclip && chown -R paperclip:paperclip /paperclip

# ── Create Hermes home directory on the persistent volume ──
RUN mkdir -p /paperclip/.hermes && chown -R paperclip:paperclip /paperclip/.hermes

WORKDIR /app

# ── Copy package files and install Node dependencies ──
COPY package.json ./
RUN npm install --omit=dev

# ── Copy application code ──
COPY . .

# ── Give ownership of everything to the non-root user ──
RUN chown -R paperclip:paperclip /app /home/paperclip

# ── Copy and set up entrypoint ──
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# ── Set Hermes home to persistent volume so memory/sessions survive redeploys ──
ENV HERMES_HOME=/paperclip/.hermes

# ── Railway injects PORT at runtime (default 3100) ──
ENV PORT=3100
EXPOSE 3100

# ── Entrypoint runs as root to fix volume permissions, then drops to paperclip user ──
ENTRYPOINT ["/entrypoint.sh"]
CMD ["npm", "start"]
