// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 vvas2002. ThunderEngine Web, https://github.com/defds7721-cyber/thunderengine-web
// This file is part of ThunderEngine. Any use of it, modified or not, including on a website,
// must stay open source under AGPL-3.0 and keep the "ThunderEngine" credit and link (NOTICE, section 7(b)).
// Геометрия рельефа: σ-координата
// CM1 (init_terrain.F, param.F:8103-8127, 8218-8234), всё во float32.
import { f } from './f32.js';
import { Grid } from './grid.js';

export class TerrainGeometry {
  // Колокол Дюррана-Клемпа (init_terrain.F:67-77, itern=1)
  static bellHill(hx, height = f(400.0), halfWidth = f(1000.0), centre = null) {
    const xc = centre ?? f(0.0 + f(f(0.5) * f(hx.dx)));
    return (i, _j) => {
      const t = f(f(f(hx.centre(i)) - xc) / halfWidth);
      return f(height / f(1.0 + f(t * t)));
    };
  }

  // init(grid:flat:zs:periodicX:periodicY:advectionOrder:)
  constructor({ grid: g, flat, zs: zsAt, periodicX, periodicY, advectionOrder = 5 }) {
    if (flat.nz !== g.nz) throw new Error('рельеф: nz плоской сетки не совпадает');
    this.grid = g;
    const h = Grid.halo, nx = g.nx, ny = g.ny, nz = g.nz;
    const sJ = g.strideJ, sK = g.strideK, plane = sJ * sK;
    const p = (i, j) => (i + h) + sJ * (j + h);
    const c = (i, j, k) => p(i, j) + plane * k;
    const sigma = flat.zh.map(f), sigmaf = flat.zf.map(f);
    const zt = sigmaf[nz];
    this.zt = zt;
    const dz = f(flat.dzNominal);
    const rdx = f(1.0 / g.dx), rdy = f(1.0 / g.dy);
    const bc2d = a => {
      for (let j = 0; j < ny; j++) for (let q = 1; q <= h; q++) {
        a[p(-q, j)] = periodicX ? a[p(nx - q, j)] : a[p(0, j)];
        a[p(nx - 1 + q, j)] = periodicX ? a[p(q - 1, j)] : a[p(nx - 1, j)];
      }
      for (let i = -h; i <= nx - 1 + h; i++) for (let q = 1; q <= h; q++) {
        a[p(i, -q)] = periodicY ? a[p(i, ny - q)] : a[p(i, 0)];
        a[p(i, ny - 1 + q)] = periodicY ? a[p(i, q - 1)] : a[p(i, ny - 1)];
      }
    };
    const Z = n => new Float32Array(n);
    const zs = Z(plane);
    for (let j = -h; j <= ny - 1 + h; j++) for (let i = -h; i <= nx - 1 + h; i++) zs[p(i, j)] = zsAt(i, j);
    bc2d(zs);
    const zh = Z(g.count), zf = Z(g.count);
    const zfBelow = Z(plane), zfAbove = Z(plane), zhBelow = Z(plane), zhAbove = Z(plane);
    for (let j = -h; j <= ny - 1 + h; j++) for (let i = -h; i <= nx - 1 + h; i++) {
      const s = zs[p(i, j)];
      for (let k = 0; k < nz; k++) zh[c(i, j, k)] = f(s + f(f(sigma[k] * f(zt - s)) / zt));
      for (let k = 0; k <= nz; k++) zf[c(i, j, k)] = f(s + f(f(sigmaf[k] * f(zt - s)) / zt));
      const f0 = zf[c(i, j, 0)], f1 = zf[c(i, j, 1)], fn = zf[c(i, j, nz)], fn1 = zf[c(i, j, nz - 1)];
      zfBelow[p(i, j)] = f(f0 - f(f1 - f0));
      zfAbove[p(i, j)] = f(fn + f(fn - fn1));
      zhBelow[p(i, j)] = f(f(0.5) * f(zfBelow[p(i, j)] + f0));
      zhAbove[p(i, j)] = f(f(0.5) * f(fn + zfAbove[p(i, j)]));
      zh[c(i, j, nz)] = zhAbove[p(i, j)];
    }
    const mh = Z(g.count), mf = Z(g.count), c1 = Z(g.count), c2 = Z(g.count);
    for (let j = -h; j <= ny - 1 + h; j++) for (let i = -h; i <= nx - 1 + h; i++) {
      for (let k = 0; k < nz; k++) mh[c(i, j, k)] = f(dz / f(zf[c(i, j, k + 1)] - zf[c(i, j, k)]));
      mh[c(i, j, nz)] = f(dz / f(zfAbove[p(i, j)] - zf[c(i, j, nz)]));
      for (let k = 0; k <= nz; k++) {
        const zhk = k < nz ? zh[c(i, j, k)] : zhAbove[p(i, j)];
        const zhk1 = k > 0 ? zh[c(i, j, k - 1)] : zhBelow[p(i, j)];
        mf[c(i, j, k)] = f(dz / f(zhk - zhk1));
        const w2 = f(f(zf[c(i, j, k)] - zhk1) / f(zhk - zhk1));
        c2[c(i, j, k)] = w2; c1[c(i, j, k)] = f(1.0 - w2);
      }
    }
    const gz = Z(plane), rgz = Z(plane), gzu = Z(plane), rgzu = Z(plane), gzv = Z(plane), rgzv = Z(plane);
    for (let j = -h; j <= ny - 1 + h; j++) for (let i = -h; i <= nx - 1 + h; i++) {
      gz[p(i, j)] = f(zt / f(zt - zs[p(i, j)])); rgz[p(i, j)] = f(f(zt - zs[p(i, j)]) / zt);
    }
    for (let j = -h; j <= ny - 1 + h; j++) for (let i = -h + 1; i <= nx - 1 + h; i++) {
      const m = f(f(0.5) * f(zs[p(i - 1, j)] + zs[p(i, j)]));
      gzu[p(i, j)] = f(zt / f(zt - m)); rgzu[p(i, j)] = f(f(zt - m) / zt);
    }
    for (let j = -h + 1; j <= ny - 1 + h; j++) for (let i = -h; i <= nx - 1 + h; i++) {
      const m = f(f(0.5) * f(zs[p(i, j - 1)] + zs[p(i, j)]));
      gzv[p(i, j)] = f(zt / f(zt - m)); rgzv[p(i, j)] = f(f(zt - m) / zt);
    }
    const gx = Z(g.count), gxu = Z(g.count), gy = Z(g.count), gyv = Z(g.count);
    for (let k = 0; k <= nz; k++) {
      const zk = f(zt - sigmaf[k]);
      for (let j = -h + 1; j <= ny - 2 + h; j++) for (let i = -h + 1; i <= nx - 2 + h; i++) {
        const uh = f(g.hx.metricCentre(i)), uf = f(g.hx.metricFace(i));
        const vh = f(g.hy.metricCentre(j)), vf = f(g.hy.metricFace(j));
        gx[c(i, j, k)] = f(f(f(f(zk * gz[p(i, j)]) * f(rgzu[p(i + 1, j)] - rgzu[p(i, j)])) * rdx) * uh);
        gxu[c(i, j, k)] = f(f(f(f(zk * gzu[p(i, j)]) * f(rgz[p(i, j)] - rgz[p(i - 1, j)])) * rdx) * uf);
        gy[c(i, j, k)] = f(f(f(f(zk * gz[p(i, j)]) * f(rgzv[p(i, j + 1)] - rgzv[p(i, j)])) * rdy) * vh);
        gyv[c(i, j, k)] = f(f(f(f(zk * gzv[p(i, j)]) * f(rgz[p(i, j)] - rgz[p(i, j - 1)])) * rdy) * vf);
      }
    }
    const K37 = f(f(37.0) / f(60.0)), K8 = f(f(-8.0) / f(60.0)), K1 = f(f(1.0) / f(60.0));
    const K7 = f(f(7.0) / f(12.0)), Km1 = f(f(-1.0) / f(12.0));
    const flx6 = (s1, s2, s3, s4, s5, s6) => f(f(f(K37 * f(s4 + s3)) + f(K8 * f(s5 + s2))) + f(K1 * f(s6 + s1)));
    const flx4 = (s1, s2, s3, s4) => f(f(K7 * f(s3 + s2)) + f(Km1 * f(s4 + s1)));
    const at = (i, j) => zs[p(i, j)];
    const zsAtU = (i, j) => {
      if (advectionOrder <= 2) return f(f(0.5) * f(at(i - 1, j) + at(i, j)));
      if (advectionOrder <= 4) return flx4(at(i - 2, j), at(i - 1, j), at(i, j), at(i + 1, j));
      if (advectionOrder <= 6) return flx6(at(i - 3, j), at(i - 2, j), at(i - 1, j), at(i, j), at(i + 1, j), at(i + 2, j));
      throw new Error(`zsgrad: порядок адвекции ${advectionOrder} не портирован (flx8/flx10)`);
    };
    const zsAtV = (i, j) => {
      if (advectionOrder <= 2) return f(f(0.5) * f(at(i, j - 1) + at(i, j)));
      if (advectionOrder <= 4) return flx4(at(i, j - 2), at(i, j - 1), at(i, j), at(i, j + 1));
      if (advectionOrder <= 6) return flx6(at(i, j - 3), at(i, j - 2), at(i, j - 1), at(i, j), at(i, j + 1), at(i, j + 2));
      throw new Error(`zsgrad: порядок адвекции ${advectionOrder} не портирован (flx8/flx10)`);
    };
    const dzdx = Z(plane), dzdy = Z(plane);
    for (let j = 0; j < ny; j++) for (let i = 0; i < nx; i++) {
      dzdx[p(i, j)] = f(f(f(zsAtU(i + 1, j) - zsAtU(i, j)) * rdx) * f(g.hx.metricCentre(i)));
    }
    if (ny > 1) for (let j = 0; j < ny; j++) for (let i = 0; i < nx; i++) {
      dzdy[p(i, j)] = f(f(f(zsAtV(i, j + 1) - zsAtV(i, j)) * rdy) * f(g.hy.metricCentre(j)));
    }
    bc2d(dzdx); bc2d(dzdy);
    const rds = new Array(nz).fill(0), rdsf = new Array(nz).fill(0);
    for (let k = 1; k < nz; k++) rds[k] = f(1.0 / f(sigma[k] - sigma[k - 1]));
    for (let k = 0; k < nz; k++) rdsf[k] = f(1.0 / f(sigmaf[k + 1] - sigmaf[k]));
    Object.assign(this, { zs, zh, zf, mh, mf, c1, c2, gz, rgz, gzu, rgzu, gzv, rgzv, dzdx, dzdy, gx, gxu, gy, gyv,
      rds, rdsf, zfBelow, zfAbove, zhBelow, zhAbove });
  }

  column(i, j) {
    const out = [];
    for (let k = 0; k < this.grid.nz; k++) out.push(this.zh[this.grid.index(i, j, k)]);
    return out;
  }
}
