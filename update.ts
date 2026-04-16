#!/usr/bin/env nix
/*
#! nix shell --inputs-from . nixpkgs#bun nixpkgs#oxfmt -c bun
*/

import { $, Glob, semver } from 'bun';
import { join } from 'node:path';

const REPO_API = 'https://api.github.com/repos/oven-sh/bun/releases';
const DOWNLOAD_BASE = 'https://github.com/oven-sh/bun/releases/download';

const platforms = {
	'x86_64-linux': 'bun-linux-x64-baseline.zip',
	'aarch64-linux': 'bun-linux-aarch64.zip',
	'x86_64-darwin': 'bun-darwin-x64-baseline.zip',
	'aarch64-darwin': 'bun-darwin-aarch64.zip',
} as const;

type NixPlatform = keyof typeof platforms;

interface ReleaseAsset {
	name: string;
	browser_download_url: string;
	digest: string | null;
}

interface Release {
	tag_name: string;
	draft: boolean;
	prerelease: boolean;
	assets: ReleaseAsset[];
}

interface SourcesJSON {
	version: string;
	platforms: Record<NixPlatform, { url: string; hash: string }>;
}

function githubHeaders(): HeadersInit {
	const headers: HeadersInit = {
		Accept: 'application/vnd.github+json',
		'X-GitHub-Api-Version': '2022-11-28',
	};
	const token = process.env.GITHUB_TOKEN;
	if (token) {
		headers.Authorization = `Bearer ${token}`;
	}
	return headers;
}

async function fetchJSON<T>(url: string): Promise<T> {
	const response = await fetch(url, {
		headers: githubHeaders(),
	});

	if (!response.ok) {
		throw new Error(`GitHub API request failed: ${response.status} ${response.statusText}`);
	}

	return (await response.json()) as T;
}

function tagToVersion(tag: string): string | null {
	const match = tag.match(/^bun-v(\d+\.\d+\.\d+)$/);
	return match ? match[1] : null;
}

async function fetchAllReleases(): Promise<Release[]> {
	const releases: Release[] = [];

	for (let page = 1; ; page++) {
		const pageReleases = await fetchJSON<Release[]>(`${REPO_API}?per_page=100&page=${page}`);
		if (pageReleases.length === 0) {
			break;
		}
		releases.push(...pageReleases.filter((release) => !release.draft && !release.prerelease));
	}

	return releases;
}

async function sha256HexToSri(sha256Hex: string): Promise<string> {
	const result =
		await $`nix hash convert --hash-algo sha256 --from base16 --to sri ${sha256Hex}`.text();
	return result.trim();
}

async function getExistingVersions(): Promise<{
	versions: Set<string>;
	latest: string | null;
}> {
	const versionsDir = join(import.meta.dir, 'versions');
	const glob = new Glob('*.json');
	const versions: string[] = [];

	for await (const f of glob.scan(versionsDir)) {
		versions.push(f.replace(/\.json$/, ''));
	}

	if (versions.length === 0) {
		return { versions: new Set(), latest: null };
	}

	versions.sort((a, b) => semver.order(a, b));
	return { versions: new Set(versions), latest: versions[versions.length - 1] };
}

async function writeVersionSources(
	version: string,
	hashes: Record<NixPlatform, string>,
): Promise<void> {
	const versionedPath = join(import.meta.dir, 'versions', `${version}.json`);

	const platformsData: Record<NixPlatform, { url: string; hash: string }> = {} as Record<
		NixPlatform,
		{ url: string; hash: string }
	>;

	for (const [nixPlatform, assetName] of Object.entries(platforms)) {
		platformsData[nixPlatform as NixPlatform] = {
			url: `${DOWNLOAD_BASE}/bun-v${version}/${assetName}`,
			hash: hashes[nixPlatform as NixPlatform],
		};
	}

	const sourcesData: SourcesJSON = {
		version,
		platforms: platformsData,
	};

	await Bun.write(versionedPath, JSON.stringify(sourcesData, null, 2) + '\n');
}

async function processRelease(release: Release): Promise<boolean> {
	const version = tagToVersion(release.tag_name);
	const hashes: Record<NixPlatform, string> = {} as Record<NixPlatform, string>;

	for (const [nixPlatform, assetName] of Object.entries(platforms)) {
		const asset = release.assets.find((candidate) => candidate.name === assetName);
		if (!asset?.digest?.startsWith('sha256:')) {
			console.warn(`  Skipping ${version}: missing digest for ${assetName}`);
			return false;
		}

		hashes[nixPlatform as NixPlatform] = await sha256HexToSri(asset.digest.slice('sha256:'.length));
	}

	await writeVersionSources(version, hashes);
	return true;
}

const { versions: existingVersions, latest: currentVersion } = await getExistingVersions();
const allReleases = (await fetchAllReleases()).filter((release) => tagToVersion(release.tag_name) !== null);
const allVersions = allReleases
	.map((release) => tagToVersion(release.tag_name))
	.filter((version): version is string => version !== null);
allVersions.sort((a, b) => semver.order(a, b));

const latestVersion = allVersions[allVersions.length - 1];

console.log(`Current version: ${currentVersion}`);
console.log(`Latest version:  ${latestVersion}`);

const existingArray = [...existingVersions].sort((a, b) => semver.order(a, b));
const earliest = existingArray[0];

const missingVersions = allVersions.filter(
	(version) =>
		!existingVersions.has(version) && (!earliest || semver.order(version, earliest) >= 0),
);

if (missingVersions.length === 0) {
	console.log('All versions are up to date!');
} else {
	console.log(`Found ${missingVersions.length} missing version(s): ${missingVersions.join(', ')}`);

	const releasesByVersion = new Map(
		allReleases.map((release) => [tagToVersion(release.tag_name), release]),
	);

	for (const version of missingVersions) {
		const release = releasesByVersion.get(version);
		if (!release) {
			console.warn(`  Skipping ${version}: release not found`);
			continue;
		}

		console.log(`Processing ${version}...`);
		const ok = await processRelease(release);
		if (ok) {
			console.log(`  Added ${version}`);
		}
	}
}

console.log('Formatting with oxfmt...');
await $`oxfmt --config ${join(import.meta.dir, '.oxfmtrc.jsonc')} versions/*.json`.quiet();
console.log('Done!');

console.log(latestVersion);
