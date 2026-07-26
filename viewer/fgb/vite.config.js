import { defineConfig } from 'vite';
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
    plugins: [
        tailwindcss(),
    ],
    // GitHub Pages のサブパス。ビューアを複数並べるため /<repo>/fgb/ に配置する。
    // 環境変数で上書きできるようにし、リポジトリ名の変更に追従できるようにする。
    base: process.env.VITE_BASE ?? '/MAFF-fude-dataset/fgb/',
});